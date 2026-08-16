"""
main.py
-------
Main Raspberry-Pi-facing application. Thin CLI wrapper around
prediction.predictor.ChargingWattPredictor.

Usage:
    python -m app.main --brand Xiaomi --model "Redmi Note 11 Pro"
    python -m app.main --brand NewBrand --model "NewPhone X" --ram_gb 12 --battery_mah 5000
    python -m app.main   (interactive mode, no args)
"""

import argparse
import logging
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

from prediction.predictor import ChargingWattPredictor, ValidationError

logging.basicConfig(level=logging.WARNING, format="%(levelname)s: %(message)s")


SPEC_ARGS = [
    ("price_inr", float), ("rating_score", float), ("processor_name", str),
    ("processor_brand", str), ("core_count", int), ("clock_speed_ghz", float),
    ("ram_gb", float), ("storage_gb", float), ("has_5g", bool), ("has_nfc", bool),
    ("has_ir_blaster", bool), ("display_inches", float), ("res_width_px", int),
    ("res_height_px", int), ("refresh_rate_hz", int), ("battery_mah", float),
    ("fast_charging", bool), ("rear_camera_count", int), ("front_camera_count", int),
    ("rear_camera_main_mp", float), ("front_camera_main_mp", float), ("os_name", str),
    ("memory_card_supported", bool),
]


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Predict maximum smartphone charging wattage.")
    parser.add_argument("--brand", help="Smartphone brand, e.g. 'Xiaomi'")
    parser.add_argument("--model", help="Smartphone model, e.g. 'Redmi Note 11 Pro'")
    for name, type_ in SPEC_ARGS:
        arg_type = str if type_ is bool else type_
        parser.add_argument(f"--{name}", type=arg_type, default=None)
    return parser


def specs_from_args(args) -> dict:
    specs = {"smartphone_brand": args.brand, "model": args.model}
    for name, type_ in SPEC_ARGS:
        value = getattr(args, name)
        if value is not None:
            if type_ is bool:
                value = str(value).strip().lower() in ("true", "1", "yes")
            specs[name] = value
    return specs


def run_interactive(predictor: ChargingWattPredictor):
    print("Smartphone Maximum Charging Wattage Predictor (interactive mode)")
    print("Type 'quit' at any prompt to exit.\n")
    while True:
        brand = input("Brand: ").strip()
        if brand.lower() == "quit":
            break
        model_name = input("Model: ").strip()
        if model_name.lower() == "quit":
            break
        specs = {"smartphone_brand": brand, "model": model_name}
        try:
            result = predictor.predict(specs)
            print("\n" + result.format() + "\n")
        except ValidationError as e:
            print(f"\nInput error: {e}\n")


def main():
    parser = build_arg_parser()
    args = parser.parse_args()

    predictor = ChargingWattPredictor()

    if not args.brand and not args.model:
        run_interactive(predictor)
        return

    specs = specs_from_args(args)
    try:
        result = predictor.predict(specs)
        print(result.format())
    except ValidationError as e:
        print(f"Input error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
