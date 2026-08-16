"""
test_system.py
---------------
Basic test suite covering the required scenarios from the project spec:
known phones, unknown phones, new brands, missing values, invalid input,
capitalization/spacing differences, and similar phone names.

Run:
    python -m pytest tests/test_system.py -v
or:
    python -m tests.test_system
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

import pytest

from prediction.predictor import ChargingWattPredictor, ValidationError


@pytest.fixture(scope="module")
def predictor():
    return ChargingWattPredictor()


def test_known_phone_exact(predictor):
    result = predictor.predict({"smartphone_brand": "xiaomi", "model": "Redmi Note 14 SE 5G"})
    assert result.source == "Verified Database Match"
    assert result.charging_watt == 45.0


def test_known_phone_case_and_spacing(predictor):
    result = predictor.predict({"smartphone_brand": "  XIAOMI ", "model": "redmi   note 14 se 5g"})
    assert result.source == "Verified Database Match"
    assert result.charging_watt == 45.0


def test_known_phone_with_ram_storage_suffix(predictor):
    result = predictor.predict({
        "smartphone_brand": "xiaomi",
        "model": "Redmi Note 14 Pro (8GB RAM + 256GB)",
    })
    assert result.source == "Verified Database Match"
    assert result.charging_watt == 45.0


def test_known_phone_without_brand_prefix_in_model(predictor):
    # dataset stores "Xiaomi Redmi Note 14 Pro Plus ...", user omits "Xiaomi"
    result = predictor.predict({
        "smartphone_brand": "xiaomi",
        "model": "Redmi Note 14 Pro Plus (12GB RAM + 512GB)",
    })
    assert result.source == "Verified Database Match"
    assert result.charging_watt == 90.0


def test_known_phone_brand_glued_to_model_no_space(predictor):
    # e.g. user types "VivoV60e" instead of "V60e" or "Vivo V60e" -- brand
    # and model glued together with no separator at all.
    result = predictor.predict({"smartphone_brand": "Vivo", "model": "VivoV60e"})
    assert result.source == "Verified Database Match"
    assert result.charging_watt == 90.0


def test_unknown_phone_with_familiar_specs_uses_ml(predictor):
    result = predictor.predict({
        "smartphone_brand": "xiaomi",
        "model": "Totally New Model Not In Dataset 9000",
        "ram_gb": 12, "battery_mah": 5000, "display_inches": 6.7,
        "refresh_rate_hz": 120, "has_5g": True, "processor_brand": "snapdragon",
        "price_inr": 35000, "storage_gb": 256, "core_count": 8, "clock_speed_ghz": 3.0,
    })
    assert result.source == "Machine Learning Prediction"
    assert result.charging_watt > 0


def test_completely_new_brand_does_not_crash(predictor):
    result = predictor.predict({
        "smartphone_brand": "BrandNewCo", "model": "Alpha One",
        "ram_gb": 8, "battery_mah": 4500, "display_inches": 6.5,
        "refresh_rate_hz": 90, "processor_brand": "mediatek", "price_inr": 18000,
    })
    assert result.source == "Machine Learning Prediction"
    assert result.charging_watt > 0


def test_missing_features_with_enough_coverage_still_predicts(predictor):
    result = predictor.predict({
        "smartphone_brand": "SomeBrand", "model": "Model Z",
        "ram_gb": 8, "battery_mah": 5000, "price_inr": 20000,
        "display_inches": 6.6, "core_count": 8,
    })
    assert result.source == "Machine Learning Prediction"


def test_missing_features_below_threshold_raises_clear_message(predictor):
    with pytest.raises(ValidationError):
        predictor.predict({"smartphone_brand": "SomeBrand", "model": "Model Z"})


def test_invalid_numeric_input_raises(predictor):
    with pytest.raises(ValidationError):
        predictor.predict({
            "smartphone_brand": "Samsung", "model": "Galaxy X",
            "battery_mah": 99999999,
        })


def test_missing_brand_raises(predictor):
    with pytest.raises(ValidationError):
        predictor.predict({"model": "Some Model"})


def test_missing_model_raises(predictor):
    with pytest.raises(ValidationError):
        predictor.predict({"smartphone_brand": "Samsung"})


def test_non_dict_input_raises(predictor):
    with pytest.raises(ValidationError):
        predictor.predict("Samsung Galaxy X")


def test_similar_phone_names_fuzzy_match(predictor):
    # Minor formatting difference from the exact dataset string should
    # still resolve via fuzzy matching within the same brand.
    result = predictor.predict({"smartphone_brand": "samsung", "model": "Galaxy S24 Ultra"})
    assert result.source == "Verified Database Match"


def test_output_format(predictor):
    result = predictor.predict({"smartphone_brand": "xiaomi", "model": "Redmi Note 14 SE 5G"})
    text = result.format()
    assert "Maximum Charging Power:" in text
    assert "Source:" in text
    assert "45W" in text


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
