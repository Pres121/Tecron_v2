"""
phone_database.py
------------------
Layer One of the prediction system: an exact / highly-reliable-match
lookup against the known smartphone dataset.

This layer is intentionally simple and dependency-light (no ML) so
that it is cheap to run on a Raspberry Pi and always preferred over
a prediction whenever a verified real-world value is available.
"""

from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Optional
import logging

import pandas as pd

from database.normalization import (
    build_match_key, normalize_brand, normalize_model, strip_brand_prefix,
)

logger = logging.getLogger(__name__)

# Similarity threshold above which a near-match is still considered
# "highly reliable" (handles minor typos / formatting differences that
# survive normalization, e.g. missing hyphen). Below this, we refuse to
# guess and fall through to the ML layer instead.
FUZZY_MATCH_THRESHOLD = 0.92


@dataclass
class DatabaseMatch:
    brand: str
    model: str
    charging_watt: float
    match_type: str  # "exact" or "fuzzy"
    similarity: float
    row: dict


class PhoneDatabase:
    """
    Wraps the known-phone CSV/DataFrame and provides normalized lookup.

    Designed so that future dataset updates (new rows appended to the
    same CSV) are picked up automatically the next time the database is
    (re)loaded -- no code changes required.
    """

    def __init__(self, dataframe: pd.DataFrame):
        self._df = dataframe.reset_index(drop=True).copy()
        self._df["_match_key"] = self._df.apply(
            lambda r: build_match_key(r["smartphone_brand"], r["model"]), axis=1
        )
        self._df["_brand_key"] = self._df["smartphone_brand"].apply(normalize_brand)
        self._df["_model_key"] = self._df.apply(
            lambda r: strip_brand_prefix(r["_brand_key"], normalize_model(r["model"])), axis=1
        )

        # If duplicate match keys exist with conflicting charging_watt values,
        # keep the most frequent / most recently seen value and log a warning
        # so the conflict is visible during dataset maintenance.
        self._resolve_conflicting_duplicates()

        self._index = {}
        for _, row in self._df.iterrows():
            self._index.setdefault(row["_match_key"], row.to_dict())

    def _resolve_conflicting_duplicates(self):
        grouped = self._df.groupby("_match_key")["charging_watt"].nunique()
        conflicting_keys = grouped[grouped > 1].index.tolist()
        if conflicting_keys:
            logger.warning(
                "Found %d phone(s) with conflicting charging_watt values across "
                "duplicate entries; keeping the most common value for each.",
                len(conflicting_keys),
            )
            for key in conflicting_keys:
                subset = self._df[self._df["_match_key"] == key]
                mode_watt = subset["charging_watt"].mode().iloc[0]
                keep_idx = subset.index[0]
                self._df.loc[keep_idx, "charging_watt"] = mode_watt
                drop_idx = subset.index[1:]
                self._df.drop(index=drop_idx, inplace=True)
            self._df.reset_index(drop=True, inplace=True)

    @classmethod
    def from_csv(cls, csv_path: str) -> "PhoneDatabase":
        df = pd.read_csv(csv_path)
        return cls(df)

    def __len__(self) -> int:
        return len(self._df)

    def lookup(self, brand: str, model: str) -> Optional[DatabaseMatch]:
        """
        Attempt to find a reliable match for the given brand/model.
        Returns None if no sufficiently reliable match exists, in which
        case the caller should fall back to the ML layer.
        """
        key = build_match_key(brand, model)

        # 1) Exact normalized match
        row = self._index.get(key)
        if row is not None:
            return DatabaseMatch(
                brand=row["smartphone_brand"],
                model=row["model"],
                charging_watt=float(row["charging_watt"]),
                match_type="exact",
                similarity=1.0,
                row=row,
            )

        # 2) Fuzzy match, restricted to the same normalized brand to avoid
        #    cross-brand false positives (e.g. matching "Note 11" across brands).
        brand_key = normalize_brand(brand)
        model_key = strip_brand_prefix(brand_key, normalize_model(model))
        best_row, best_score = None, 0.0
        for _, row in self._df[self._df["_brand_key"] == brand_key].iterrows():
            score = SequenceMatcher(None, model_key, row["_model_key"]).ratio()
            if score > best_score:
                best_score, best_row = score, row

        if best_row is not None and best_score >= FUZZY_MATCH_THRESHOLD:
            return DatabaseMatch(
                brand=best_row["smartphone_brand"],
                model=best_row["model"],
                charging_watt=float(best_row["charging_watt"]),
                match_type="fuzzy",
                similarity=best_score,
                row=best_row.to_dict(),
            )

        return None
