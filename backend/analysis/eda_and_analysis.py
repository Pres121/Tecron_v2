"""
eda_and_analysis.py
--------------------
Exploratory data analysis for the smartphone charging-wattage dataset.
Produces PNG charts into analysis/output/ and prints a text summary.

Run:
    python -m analysis.eda_and_analysis

(A plain script is used instead of a .ipynb notebook so it can run
head-lessly / be version-controlled cleanly; the same code can be pasted
into notebook cells if interactive exploration is preferred.)
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from training.data_cleaning import clean_dataset
from training.feature_engineering import add_engineered_features

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_PATH = BASE_DIR / "data" / "smartphone_dataset.csv"
OUTPUT_DIR = Path(__file__).resolve().parent / "output"

sns.set_theme(style="whitegrid")


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)
    raw_df = pd.read_csv(DATA_PATH)
    df = add_engineered_features(clean_dataset(raw_df))

    print(f"Rows: {len(df)}, Columns: {df.shape[1]}")
    print("\nTarget (charging_watt) summary:")
    print(df["charging_watt"].describe())
    print(f"Skewness: {df['charging_watt'].skew():.3f}")

    # 1. Target distribution
    plt.figure(figsize=(8, 5))
    sns.histplot(df["charging_watt"], bins=25, kde=True)
    plt.title("Distribution of Maximum Charging Wattage")
    plt.xlabel("Charging Watt (W)")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "target_distribution.png", dpi=120)
    plt.close()

    # 2. Correlation heatmap
    numeric_cols = [
        "price_inr", "rating_score", "core_count", "clock_speed_ghz",
        "ram_gb", "storage_gb", "display_inches", "refresh_rate_hz",
        "battery_mah", "rear_camera_main_mp", "front_camera_main_mp",
        "charging_watt",
    ]
    plt.figure(figsize=(9, 7))
    sns.heatmap(df[numeric_cols].corr(), annot=True, fmt=".2f", cmap="coolwarm", center=0)
    plt.title("Correlation with Charging Wattage")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "correlation_heatmap.png", dpi=120)
    plt.close()

    # 3. Battery vs charging watt
    plt.figure(figsize=(8, 5))
    sns.scatterplot(data=df, x="battery_mah", y="charging_watt", alpha=0.5)
    plt.title("Battery Capacity vs Charging Wattage")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "battery_vs_watt.png", dpi=120)
    plt.close()

    # 4. RAM vs charging watt
    plt.figure(figsize=(8, 5))
    sns.boxplot(data=df, x="ram_gb", y="charging_watt")
    plt.title("RAM vs Charging Wattage")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "ram_vs_watt.png", dpi=120)
    plt.close()

    # 5. Refresh rate vs charging watt
    plt.figure(figsize=(8, 5))
    sns.boxplot(data=df, x="refresh_rate_hz", y="charging_watt")
    plt.title("Refresh Rate vs Charging Wattage")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "refresh_rate_vs_watt.png", dpi=120)
    plt.close()

    # 6. Price vs charging watt
    plt.figure(figsize=(8, 5))
    sns.scatterplot(data=df, x="price_inr", y="charging_watt", alpha=0.5)
    plt.xscale("log")
    plt.title("Price (log scale) vs Charging Wattage")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "price_vs_watt.png", dpi=120)
    plt.close()

    # 7. Brand-level patterns (top 12 brands by count)
    top_brands = df["smartphone_brand"].value_counts().head(12).index
    plt.figure(figsize=(11, 6))
    sns.boxplot(data=df[df["smartphone_brand"].isin(top_brands)],
                x="smartphone_brand", y="charging_watt")
    plt.xticks(rotation=45, ha="right")
    plt.title("Charging Wattage Distribution by Brand (Top 12 by count)")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "brand_vs_watt.png", dpi=120)
    plt.close()

    # 8. Clock speed vs charging watt
    plt.figure(figsize=(8, 5))
    sns.scatterplot(data=df, x="clock_speed_ghz", y="charging_watt", alpha=0.5)
    plt.title("Processor Clock Speed vs Charging Wattage")
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "clockspeed_vs_watt.png", dpi=120)
    plt.close()

    print(f"\nSaved 8 charts to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
