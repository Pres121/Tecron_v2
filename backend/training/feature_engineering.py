"""
feature_engineering.py
-----------------------
Reusable feature engineering shared by training and inference. Every
feature here is computable purely from specs a user would provide for
a *new, unreleased* phone -- nothing derived from the target
(charging_watt) or from anything only knowable after the fact, so the
pipeline is safe from data leakage.

Categorical encoding (brand / processor) is done inside the sklearn
Pipeline in train_model.py via OneHotEncoder(handle_unknown="ignore"),
not here, so that unseen brands/processors at inference time never
crash the model.
"""

import numpy as np
import pandas as pd

# Feature columns actually fed into the model (after this module runs).
NUMERIC_FEATURES = [
    "price_inr", "rating_score", "core_count", "clock_speed_ghz",
    "ram_gb", "storage_gb", "display_inches", "refresh_rate_hz",
    "battery_mah", "rear_camera_count", "front_camera_count",
    "rear_camera_main_mp", "front_camera_main_mp",
    "total_pixels", "pixels_per_inch", "battery_per_inch",
    "ram_per_core", "performance_score",
]

BOOLEAN_FEATURES = ["has_5g", "has_nfc", "has_ir_blaster", "fast_charging",
                     "memory_card_supported"]

CATEGORICAL_FEATURES = ["smartphone_brand", "processor_brand", "os_name",
                         "device_tier"]

ALL_FEATURES = NUMERIC_FEATURES + BOOLEAN_FEATURES + CATEGORICAL_FEATURES


def _device_tier(price: float) -> str:
    """
    Bucket price into a device tier. Thresholds are in INR and reflect
    common Indian smartphone market segmentation. This is derived only
    from price (a spec known before charging wattage is decided), so it
    does not leak the target.
    """
    if price < 15000:
        return "budget"
    if price < 30000:
        return "midrange"
    if price < 60000:
        return "upper_midrange"
    return "flagship"


def add_engineered_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add derived features on top of a cleaned dataframe. Non-destructive."""
    df = df.copy()

    # --- Display features ---
    df["total_pixels"] = df["res_width_px"].astype(float) * df["res_height_px"].astype(float)
    df["pixels_per_inch"] = np.sqrt(
        df["res_width_px"].astype(float) ** 2 + df["res_height_px"].astype(float) ** 2
    ) / df["display_inches"].replace(0, np.nan)
    df["pixels_per_inch"] = df["pixels_per_inch"].fillna(df["pixels_per_inch"].median())

    # --- Battery / performance ratios ---
    df["battery_per_inch"] = df["battery_mah"] / df["display_inches"].replace(0, np.nan)
    df["battery_per_inch"] = df["battery_per_inch"].fillna(df["battery_per_inch"].median())

    df["ram_per_core"] = df["ram_gb"] / df["core_count"].replace(0, np.nan)
    df["ram_per_core"] = df["ram_per_core"].fillna(df["ram_per_core"].median())

    # A simple, transparent composite performance score (core_count * clock
    # speed) rather than a black-box index -- easy to reason about and to
    # recompute for any future phone.
    df["performance_score"] = df["core_count"] * df["clock_speed_ghz"]

    # --- Device tier from price ---
    df["device_tier"] = df["price_inr"].apply(_device_tier)

    # Ensure boolean features exist and are proper bool
    for col in BOOLEAN_FEATURES:
        if col not in df.columns:
            df[col] = False
        df[col] = df[col].astype(bool)

    return df


def select_feature_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Return only the model input columns, in a fixed order."""
    for col in ALL_FEATURES:
        if col not in df.columns:
            df[col] = np.nan
    return df[ALL_FEATURES]
