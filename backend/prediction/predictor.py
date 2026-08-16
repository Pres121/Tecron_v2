"""
predictor.py
------------
Orchestrates the two-layer prediction architecture:

    Input Validation -> Normalization -> Known Phone Lookup
        -> (hit)  Return verified wattage
        -> (miss) Feature Preparation -> ML Model -> Predicted wattage

This is the only module app/main.py needs to import. It is deliberately
lightweight at import time (loads a single pickled sklearn Pipeline) so
it is fast to start on a Raspberry Pi.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
import logging

import joblib
import pandas as pd

from database.phone_database import PhoneDatabase
from training.data_cleaning import clean_dataset
from training.feature_engineering import add_engineered_features, select_feature_frame

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DATA_PATH = BASE_DIR / "data" / "smartphone_dataset.csv"
DEFAULT_MODEL_PATH = BASE_DIR / "models" / "charging_watt_model.pkl"

# Fields that are genuinely required to attempt even an ML prediction.
# Everything else has a sane default / can be imputed.
REQUIRED_FIELDS = ["smartphone_brand", "model", "battery_mah", "ram_gb"]

# Default values used to fill in specs the caller didn't provide, so the
# pipeline never crashes on partial input. These mirror roughly-median
# values from the training dataset and are intentionally conservative.
DEFAULT_SPEC_VALUES = {
    "price_inr": 20000,
    "rating_score": 65,
    "processor_name": "unknown",
    "processor_brand": "unknown",
    "core_count": 8,
    "clock_speed_ghz": 2.0,
    "ram_gb": 6,
    "storage_gb": 128,
    "has_5g": False,
    "has_nfc": False,
    "has_ir_blaster": False,
    "display_inches": 6.5,
    "res_width_px": 1080,
    "res_height_px": 2400,
    "refresh_rate_hz": 90,
    "battery_mah": 5000,
    "fast_charging": True,
    "rear_camera_count": 2,
    "front_camera_count": 1,
    "rear_camera_main_mp": 50.0,
    "front_camera_main_mp": 16.0,
    "os_name": "android",
    "memory_card_supported": False,
    "memory_card_type": "none",
}


class ValidationError(Exception):
    """Raised when user input is missing critical, non-defaultable information."""


@dataclass
class PredictionResult:
    brand: str
    model: str
    charging_watt: float
    source: str  # "Verified Database Match" or "Machine Learning Prediction"
    confidence_note: Optional[str] = None
    matched_row: Optional[dict] = field(default=None, repr=False)

    def format(self) -> str:
        lines = [
            f"Phone: {self.brand.title()} {self.model}",
            f"Maximum Charging Power: {self._format_watt()}",
            f"Source: {self.source}",
        ]
        if self.confidence_note:
            lines.append(f"Note: {self.confidence_note}")
        return "\n".join(lines)

    def _format_watt(self) -> str:
        w = self.charging_watt
        return f"{w:.0f}W" if float(w).is_integer() else f"{w:.1f}W"


class ChargingWattPredictor:
    """
    Loads the known-phone database and the trained ML pipeline once, then
    serves predictions cheaply. Intended to be instantiated a single time
    (e.g. at application startup) and reused for every request.
    """

    def __init__(self, data_path: Path = DEFAULT_DATA_PATH,
                 model_path: Path = DEFAULT_MODEL_PATH):
        logger.info("Loading known-phone database from %s", data_path)
        self.database = PhoneDatabase.from_csv(str(data_path))
        logger.info("Database ready with %d known phones.", len(self.database))

        logger.info("Loading trained ML pipeline from %s", model_path)
        if not Path(model_path).exists():
            raise FileNotFoundError(
                f"No trained model found at {model_path}. "
                f"Run `python -m training.train_model` first."
            )
        self.ml_pipeline = joblib.load(model_path)
        logger.info("ML pipeline loaded.")

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def predict(self, phone_specs: dict) -> PredictionResult:
        """
        phone_specs: dict with at least 'smartphone_brand' and 'model'.
        Additional spec keys (see DEFAULT_SPEC_VALUES) improve ML accuracy
        when the phone is not in the known database, but are optional.
        """
        self._validate_input(phone_specs)
        brand = str(phone_specs["smartphone_brand"]).strip()
        model_name = str(phone_specs["model"]).strip()

        # --- Layer 1: known-phone database lookup ---
        match = self.database.lookup(brand, model_name)
        if match is not None:
            note = None
            if match.match_type == "fuzzy":
                note = (f"Matched to closest known entry '{match.brand} {match.model}' "
                        f"(similarity {match.similarity:.0%}).")
            return PredictionResult(
                brand=brand, model=model_name,
                charging_watt=match.charging_watt,
                source="Verified Database Match",
                confidence_note=note,
                matched_row=match.row,
            )

        # --- Layer 2: ML fallback ---
        return self._predict_with_ml(brand, model_name, phone_specs)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _validate_input(self, phone_specs: dict):
        if not isinstance(phone_specs, dict):
            raise ValidationError("phone_specs must be a dictionary.")
        for field_name in ["smartphone_brand", "model"]:
            value = phone_specs.get(field_name)
            if value is None or str(value).strip() == "":
                raise ValidationError(
                    f"'{field_name}' is required to identify the phone."
                )
        # Numeric sanity checks on anything the caller did provide.
        numeric_bounds = {
            "battery_mah": (300, 30000),
            "ram_gb": (0, 64),
            "storage_gb": (0, 4096),
            "display_inches": (2.0, 12.0),
            "clock_speed_ghz": (0.3, 6.0),
            "price_inr": (0, 5_000_000),
        }
        for field_name, (lo, hi) in numeric_bounds.items():
            if field_name in phone_specs and phone_specs[field_name] is not None:
                try:
                    val = float(phone_specs[field_name])
                except (TypeError, ValueError):
                    raise ValidationError(f"'{field_name}' must be numeric.")
                if not (lo <= val <= hi):
                    raise ValidationError(
                        f"'{field_name}'={val} is outside the plausible range [{lo}, {hi}]."
                    )

    def _predict_with_ml(self, brand: str, model_name: str, phone_specs: dict) -> PredictionResult:
        # How much of the input was actually supplied vs. defaulted, to
        # decide whether the prediction is reliable enough to return.
        known_fields = [f for f in DEFAULT_SPEC_VALUES if phone_specs.get(f) is not None]
        coverage = len(known_fields) / len(DEFAULT_SPEC_VALUES)

        if coverage < 0.15:
            raise ValidationError(
                "Not enough specifications were provided to make a reliable "
                "prediction. Please supply more details (e.g. battery capacity, "
                "RAM, display, processor)."
            )

        row = dict(DEFAULT_SPEC_VALUES)
        row.update({k: v for k, v in phone_specs.items() if v is not None})
        row["smartphone_brand"] = brand
        row["model"] = model_name
        row["charging_watt"] = None  # unknown, will not be used for prediction

        raw_df = pd.DataFrame([row])
        # clean_dataset() drops rows with a non-positive/missing target, so a
        # positive placeholder is used here purely to satisfy that schema
        # check; it is discarded immediately after (never fed to the model).
        clean_df = clean_dataset(raw_df.assign(charging_watt=1))
        feat_df = add_engineered_features(clean_df)
        X = select_feature_frame(feat_df)

        prediction = float(self.ml_pipeline.predict(X)[0])
        prediction = max(2.0, round(prediction, 1))  # charging watt can't be <= 0

        note = None
        if coverage < 0.5:
            note = ("Prediction is based on limited specifications; accuracy may be "
                    "lower than usual. Provide more specs for a more reliable estimate.")

        return PredictionResult(
            brand=brand, model=model_name,
            charging_watt=prediction,
            source="Machine Learning Prediction",
            confidence_note=note,
        )
