"""
train_model.py
---------------
End-to-end training script for the charging-wattage ML fallback layer.

Run:
    python -m training.train_model

Pipeline:
    Load -> Clean -> Engineer features -> Split (grouped, leakage-safe)
    -> Train & compare candidate models -> Select best on validation MAE
    -> Refit best model on train+val -> Evaluate on held-out test set
    -> Save model + preprocessing pipeline + metadata

The saved artifacts (models/charging_watt_model.pkl) are everything the
Raspberry Pi inference code needs; training itself is meant to run on a
more powerful machine.
"""

import json
import logging
import time
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import (
    ExtraTreesRegressor,
    GradientBoostingRegressor,
    HistGradientBoostingRegressor,
    RandomForestRegressor,
)
from sklearn.dummy import DummyRegressor
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.metrics import (
    mean_absolute_error,
    median_absolute_error,
    mean_squared_error,
    r2_score,
)
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

import sys
sys.path.append(str(Path(__file__).resolve().parents[1]))

from training.data_cleaning import clean_dataset
from training.feature_engineering import (
    add_engineered_features, select_feature_frame,
    NUMERIC_FEATURES, BOOLEAN_FEATURES, CATEGORICAL_FEATURES,
)
from database.normalization import normalize_model

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_PATH = BASE_DIR / "data" / "smartphone_dataset.csv"
MODEL_DIR = BASE_DIR / "models"
MODEL_PATH = MODEL_DIR / "charging_watt_model.pkl"
METADATA_PATH = MODEL_DIR / "model_metadata.json"

RANDOM_STATE = 42


def build_preprocessor() -> ColumnTransformer:
    """Preprocessing shared by every candidate model."""
    return ColumnTransformer(
        transformers=[
            ("num", StandardScaler(), NUMERIC_FEATURES),
            ("bool", "passthrough", BOOLEAN_FEATURES),
            ("cat", OneHotEncoder(handle_unknown="ignore", min_frequency=3),
             CATEGORICAL_FEATURES),
        ]
    )


def candidate_models() -> dict:
    return {
        "MeanBaseline": DummyRegressor(strategy="median"),
        "LinearRegression": LinearRegression(),
        "Ridge": Ridge(alpha=1.0, random_state=RANDOM_STATE),
        "RandomForest": RandomForestRegressor(
            n_estimators=300, max_depth=12, min_samples_leaf=2,
            random_state=RANDOM_STATE, n_jobs=-1,
        ),
        "ExtraTrees": ExtraTreesRegressor(
            n_estimators=300, max_depth=14, min_samples_leaf=2,
            random_state=RANDOM_STATE, n_jobs=-1,
        ),
        "GradientBoosting": GradientBoostingRegressor(
            n_estimators=200, max_depth=3, learning_rate=0.05,
            random_state=RANDOM_STATE,
        ),
        "HistGradientBoosting": HistGradientBoostingRegressor(
            max_depth=6, learning_rate=0.06, max_iter=300,
            random_state=RANDOM_STATE,
        ),
    }


def evaluate(pipeline, X, y) -> dict:
    preds = pipeline.predict(X)
    return {
        "MAE": mean_absolute_error(y, preds),
        "RMSE": float(np.sqrt(mean_squared_error(y, preds))),
        "R2": r2_score(y, preds),
        "MedianAE": median_absolute_error(y, preds),
    }


def grouped_split(df: pd.DataFrame, group_col: str, test_size: float, random_state: int):
    splitter = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
    idx_a, idx_b = next(splitter.split(df, groups=df[group_col]))
    return df.iloc[idx_a].reset_index(drop=True), df.iloc[idx_b].reset_index(drop=True)


def main():
    logger.info("Loading raw dataset from %s", DATA_PATH)
    raw_df = pd.read_csv(DATA_PATH)
    logger.info("Raw shape: %s", raw_df.shape)

    logger.info("Cleaning dataset...")
    clean_df = clean_dataset(raw_df)
    logger.info("Clean shape: %s", clean_df.shape)

    logger.info("Engineering features...")
    feat_df = add_engineered_features(clean_df)

    # Grouping key: near-duplicate variants of the same base model (differing
    # only by RAM/storage) must land entirely in train OR entirely in
    # test/val, never split across them -- otherwise the model could
    # "memorize" a variant it saw in training when evaluated on its sibling.
    feat_df["_group"] = feat_df["smartphone_brand"] + "::" + feat_df["model"].apply(normalize_model)

    X_full = feat_df.copy()
    y_full = feat_df["charging_watt"].astype(float)

    # 70/15/15 grouped split
    train_df, temp_df = grouped_split(feat_df, "_group", test_size=0.30, random_state=RANDOM_STATE)
    val_df, test_df = grouped_split(temp_df, "_group", test_size=0.50, random_state=RANDOM_STATE)
    logger.info("Train/Val/Test sizes: %d / %d / %d", len(train_df), len(val_df), len(test_df))

    X_train, y_train = select_feature_frame(train_df), train_df["charging_watt"].astype(float)
    X_val, y_val = select_feature_frame(val_df), val_df["charging_watt"].astype(float)
    X_test, y_test = select_feature_frame(test_df), test_df["charging_watt"].astype(float)

    results = []
    fitted_pipelines = {}

    for name, model in candidate_models().items():
        pipeline = Pipeline([
            ("preprocess", build_preprocessor()),
            ("model", model),
        ])
        t0 = time.time()
        pipeline.fit(X_train, y_train)
        train_time = time.time() - t0

        t0 = time.time()
        val_metrics = evaluate(pipeline, X_val, y_val)
        predict_time = (time.time() - t0) / max(len(X_val), 1)

        results.append({
            "Model": name,
            "MAE": round(val_metrics["MAE"], 3),
            "RMSE": round(val_metrics["RMSE"], 3),
            "R2": round(val_metrics["R2"], 4),
            "MedianAE": round(val_metrics["MedianAE"], 3),
            "TrainTime_s": round(train_time, 3),
            "PredictTime_ms_per_row": round(predict_time * 1000, 4),
        })
        fitted_pipelines[name] = pipeline
        logger.info("%-22s val MAE=%.2fW  RMSE=%.2fW  R2=%.3f", name,
                    val_metrics["MAE"], val_metrics["RMSE"], val_metrics["R2"])

    results_df = pd.DataFrame(results).sort_values("MAE")
    print("\n=== Model Comparison (validation set) ===")
    print(results_df.to_string(index=False))

    best_name = results_df.iloc[0]["Model"]
    logger.info("Selected best model: %s", best_name)

    # Refit the winning model architecture on train+val, then report the
    # final, untouched-until-now test set performance.
    best_model_ctor = candidate_models()[best_name]
    final_pipeline = Pipeline([
        ("preprocess", build_preprocessor()),
        ("model", best_model_ctor),
    ])
    trainval_df = pd.concat([train_df, val_df], ignore_index=True)
    X_trainval = select_feature_frame(trainval_df)
    y_trainval = trainval_df["charging_watt"].astype(float)
    final_pipeline.fit(X_trainval, y_trainval)

    test_metrics = evaluate(final_pipeline, X_test, y_test)
    print("\n=== Final Held-Out Test Performance ({}) ===".format(best_name))
    for k, v in test_metrics.items():
        print(f"{k}: {v:.3f}")

    # Refit once more on ALL available data before shipping, so the
    # deployed model benefits from every known phone (standard practice
    # once model selection/evaluation is complete).
    X_all = select_feature_frame(feat_df)
    y_all = feat_df["charging_watt"].astype(float)
    final_pipeline.fit(X_all, y_all)

    MODEL_DIR.mkdir(exist_ok=True)
    joblib.dump(final_pipeline, MODEL_PATH)
    logger.info("Saved final pipeline to %s", MODEL_PATH)

    metadata = {
        "best_model": best_name,
        "trained_on_rows": len(feat_df),
        "features": {
            "numeric": NUMERIC_FEATURES,
            "boolean": BOOLEAN_FEATURES,
            "categorical": CATEGORICAL_FEATURES,
        },
        "validation_comparison": results,
        "test_metrics": test_metrics,
        "random_state": RANDOM_STATE,
        "target": "charging_watt",
        "sklearn_pipeline_includes_preprocessing": True,
    }
    with open(METADATA_PATH, "w") as f:
        json.dump(metadata, f, indent=2)
    logger.info("Saved metadata to %s", METADATA_PATH)


if __name__ == "__main__":
    main()
