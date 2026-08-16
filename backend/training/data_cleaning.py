"""
data_cleaning.py
-----------------
Reusable data cleaning logic shared by training and (if ever needed)
re-cleaning of updated datasets. Kept separate from feature engineering
so that "fixing/validating raw values" and "creating new features" are
not tangled together.

Design notes (see README for full data-quality report):
- The raw dataset arrives with numeric columns already parsed (no "8 GB"
  style strings), so type coercion here is defensive rather than the
  primary job -- it protects the pipeline against future dataset updates
  that might reintroduce unit suffixes.
- Missing values:
    * front_camera_main_mp (few missing): phones with no front camera
      report NaN. We treat this as a genuine 0 (no front camera) rather
      than imputing a plausible-but-wrong value, since 0 is factually
      correct for that class of device.
    * memory_card_supported / memory_card_type (many missing): NaN means
      "not specified / not supported". Filled with False / "none".
  No rows are dropped for missingness -- the affected columns are not
  critical enough to justify losing data, and the missingness itself is
  meaningful (not random).
- Duplicates: exact duplicate rows are dropped. Duplicate phone models
  with conflicting charging_watt are resolved at the database layer
  (see database/phone_database.py) using the majority value; for
  training we keep one row per conflicting duplicate using the same
  majority-vote rule so the two layers stay consistent.
- Outliers are NOT removed automatically. Extreme-but-real values
  (e.g. 21200 mAh rugged-phone batteries, 24GB RAM flagships, 2TB
  storage) are kept because they represent real shipped smartphones.
  Only physically impossible values (e.g. charging_watt <= 0,
  ram_gb <= 0) would be treated as data-entry errors, and none were
  found in the current dataset.
"""

import logging
import re

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

NUMERIC_COLUMNS = [
    "price_inr", "rating_score", "core_count", "clock_speed_ghz",
    "ram_gb", "storage_gb", "display_inches", "res_width_px",
    "res_height_px", "refresh_rate_hz", "battery_mah", "charging_watt",
    "rear_camera_count", "front_camera_count", "rear_camera_main_mp",
    "front_camera_main_mp",
]

BOOLEAN_COLUMNS = ["has_5g", "has_nfc", "has_ir_blaster", "fast_charging"]

_UNIT_SUFFIX_PATTERN = re.compile(r"[a-zA-Z%]+$")


def _coerce_numeric(series: pd.Series) -> pd.Series:
    """Strip common unit suffixes (e.g. '8 GB' -> 8, '67W' -> 67) and cast to numeric."""
    if pd.api.types.is_numeric_dtype(series):
        return series
    cleaned = (
        series.astype(str)
        .str.strip()
        .str.replace(",", "", regex=False)
        .str.replace(_UNIT_SUFFIX_PATTERN, "", regex=True)
        .str.strip()
    )
    return pd.to_numeric(cleaned, errors="coerce")


def _coerce_boolean(series: pd.Series) -> pd.Series:
    if series.dtype == bool:
        return series
    mapping = {"true": True, "false": False, "yes": True, "no": False,
               "1": True, "0": False, "1.0": True, "0.0": False}
    return (
        series.astype(str).str.strip().str.lower().map(mapping).fillna(False).astype(bool)
    )


def clean_dataset(df: pd.DataFrame) -> pd.DataFrame:
    """Apply the full cleaning pipeline and return a clean copy of the dataframe."""
    df = df.copy()

    # --- Text normalization for identifying columns ---
    for col in ["smartphone_brand", "processor_name", "processor_brand", "os_name"]:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip().str.lower()
    if "model" in df.columns:
        df["model"] = df["model"].astype(str).str.strip()

    # --- Numeric coercion (defensive; handles unit suffixes if present) ---
    for col in NUMERIC_COLUMNS:
        if col in df.columns:
            df[col] = _coerce_numeric(df[col])

    # --- Boolean coercion ---
    for col in BOOLEAN_COLUMNS:
        if col in df.columns:
            df[col] = _coerce_boolean(df[col])

    # --- Missing value handling ---
    if "front_camera_main_mp" in df.columns:
        # NaN genuinely means "no front camera" -> 0, not an unknown to impute.
        n_missing = df["front_camera_main_mp"].isna().sum()
        if n_missing:
            logger.info("Filling %d missing front_camera_main_mp values with 0 "
                        "(no front camera).", n_missing)
        df["front_camera_main_mp"] = df["front_camera_main_mp"].fillna(0)

    if "memory_card_supported" in df.columns:
        df["memory_card_supported"] = df["memory_card_supported"].fillna(False).astype(bool)
    if "memory_card_type" in df.columns:
        df["memory_card_type"] = df["memory_card_type"].fillna("none").astype(str).str.lower()

    # Any remaining numeric NaNs (unexpected future dataset issues) -> median impute,
    # logged so it is never a silent operation.
    for col in NUMERIC_COLUMNS:
        if col in df.columns and df[col].isna().any() and col != "charging_watt":
            median_val = df[col].median()
            n_missing = df[col].isna().sum()
            logger.warning("Median-imputing %d missing values in '%s' with %s",
                           n_missing, col, median_val)
            df[col] = df[col].fillna(median_val)

    # Rows with a missing target cannot be used for training and are dropped
    # (this is the one column where imputation would be meaningless).
    if "charging_watt" in df.columns:
        before = len(df)
        df = df.dropna(subset=["charging_watt"])
        dropped = before - len(df)
        if dropped:
            logger.warning("Dropped %d rows with missing target (charging_watt).", dropped)
        # Physically impossible values -> treat as data-entry errors and drop.
        invalid = df[df["charging_watt"] <= 0]
        if len(invalid):
            logger.warning("Dropping %d rows with non-positive charging_watt.", len(invalid))
            df = df[df["charging_watt"] > 0]

    # --- Duplicate handling ---
    exact_dupes = df.duplicated().sum()
    if exact_dupes:
        logger.info("Dropping %d fully duplicated rows.", exact_dupes)
        df = df.drop_duplicates()

    if {"smartphone_brand", "model"}.issubset(df.columns):
        key = df["smartphone_brand"] + "::" + df["model"].str.lower()
        conflict_groups = df.groupby(key)["charging_watt"].nunique()
        conflicting = conflict_groups[conflict_groups > 1]
        if len(conflicting):
            logger.warning(
                "%d phone model(s) have conflicting charging_watt values; "
                "keeping the majority value for each.", len(conflicting)
            )
            def _resolve(group):
                if group["charging_watt"].nunique() > 1:
                    mode_val = group["charging_watt"].mode().iloc[0]
                    group = group.iloc[[0]].copy()
                    group["charging_watt"] = mode_val
                return group
            df = df.groupby(key, group_keys=False).apply(_resolve).reset_index(drop=True)

    df = df.reset_index(drop=True)
    return df
