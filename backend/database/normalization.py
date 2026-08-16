"""
normalization.py
-----------------
Utilities for normalizing smartphone brand and model names so that
lookups are robust to capitalization, spacing, and common formatting
inconsistencies (e.g. "Xiaomi  redmi note 11 PRO" vs "xiaomi redmi note 11 pro").

These functions are used by BOTH:
  - the exact-match database lookup (database/phone_database.py)
  - the ML pipeline's categorical preprocessing (training/feature_engineering.py)

so that the two layers treat brand/model text consistently.
"""

import re
import unicodedata

# Common tokens that appear in a "model" string but do not affect the
# physical identity of the phone (RAM/storage variant descriptors,
# marketing suffixes, punctuation noise). They are stripped only when
# building the *matching key*, never when displaying the phone to the user.
_VARIANT_PATTERN = re.compile(
    r"\(?\s*\d+\s*gb\s*ram\s*\+?\s*\d*\s*gb?\s*(storage|rom)?\s*\)?", re.IGNORECASE
)
_RAM_STORAGE_PATTERN = re.compile(
    r"\(?\s*\d+\s*\/\s*\d+\s*gb\s*\)?|\(?\s*\d+\s*gb\s*\+\s*\d+\s*gb\s*\)?", re.IGNORECASE
)
_MULTISPACE_PATTERN = re.compile(r"\s+")
_NON_ALNUM_PATTERN = re.compile(r"[^a-z0-9 ]")

# Known brand aliasing, in case future dataset updates introduce
# inconsistent spellings for the same brand.
_BRAND_ALIASES = {
    "iqoo": "iqoo",
    "i-qoo": "iqoo",
    "one plus": "oneplus",
    "one-plus": "oneplus",
    "cmf by nothing": "cmf",
}


def _strip_accents(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def normalize_text(value: str) -> str:
    """Lowercase, strip accents, collapse whitespace, remove punctuation."""
    if value is None:
        return ""
    text = str(value).strip().lower()
    text = _strip_accents(text)
    text = _NON_ALNUM_PATTERN.sub(" ", text)
    text = _MULTISPACE_PATTERN.sub(" ", text).strip()
    return text


def normalize_brand(brand: str) -> str:
    """Normalize a smartphone brand name for matching."""
    norm = normalize_text(brand)
    return _BRAND_ALIASES.get(norm, norm)


def normalize_model(model: str) -> str:
    """
    Normalize a smartphone model string into a matching key.

    Removes RAM/storage variant descriptors (e.g. "(4GB RAM + 128GB)")
    since the same physical phone often appears in the wild with
    different variant suffixes, but should still resolve to the same
    charging wattage entry (charging wattage rarely varies by RAM/storage
    variant of the same model).
    """
    text = str(model).strip().lower()
    text = _VARIANT_PATTERN.sub(" ", text)
    text = _RAM_STORAGE_PATTERN.sub(" ", text)
    text = normalize_text(text)
    return text


def strip_brand_prefix(brand_key: str, model_key: str) -> str:
    """Remove a leading normalized-brand token from a normalized model key, if present.

    Handles both the space-separated case ("vivo y19s 5g" -> "y19s 5g")
    and the glued-together case with no separator at all, which happens
    when a user types brand and model as one word, e.g. "VivoY19"
    normalizes to "vivoy19" (no space survives normalization since there
    is no punctuation to split on) -> "y19".
    """
    if not brand_key:
        return model_key
    if model_key.startswith(brand_key + " "):
        return model_key[len(brand_key) + 1:]
    if model_key.startswith(brand_key) and len(model_key) > len(brand_key):
        return model_key[len(brand_key):]
    return model_key


def build_match_key(brand: str, model: str) -> str:
    """Build the canonical key used for exact-match dataset lookup.

    Strips a leading brand-name prefix from the model portion, since
    dataset entries are often brand-prefixed ("Xiaomi Redmi Note 14 Pro")
    while users commonly type just the model ("Redmi Note 14 Pro").
    """
    brand_key = normalize_brand(brand)
    model_key = strip_brand_prefix(brand_key, normalize_model(model))
    return f"{brand_key}::{model_key}"
