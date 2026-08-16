# Smartphone Maximum Charging Wattage Prediction System

Predicts the maximum charging power (in watts) a smartphone can accept,
using a verified database value whenever the phone is known, and a
machine learning prediction when it isn't. Designed to run on a
Raspberry Pi for inference, with heavier training done on a regular
computer.

## 1. Project Purpose

Given a phone's brand/model (and optionally its specs), return:

```
Maximum Charging Power: 67W
Source: Verified Database Match
```

or, for a phone the system has never seen:

```
Maximum Charging Power: 82.4W
Source: Machine Learning Prediction
```

## 2. System Architecture

```
User Input
    ↓
Input Validation and Cleaning        (prediction/predictor.py)
    ↓
Brand / Model Normalization          (database/normalization.py)
    ↓
Known Phone Database Lookup          (database/phone_database.py)
    ├── Reliable match found → return known charging_watt (Layer 1)
    └── No reliable match
           ↓
        Feature Preparation          (training/feature_engineering.py)
           ↓
        Trained ML Pipeline          (models/charging_watt_model.pkl)
           ↓
        Predicted charging_watt (Layer 2)
```

### Directory layout

```
phone_charging_predictor/
├── data/
│   └── smartphone_dataset.csv        # source of truth for both layers
├── models/
│   ├── charging_watt_model.pkl       # trained sklearn Pipeline (preprocessing + model, single file)
│   └── model_metadata.json           # which model won, validation/test metrics
├── training/
│   ├── data_cleaning.py              # reusable cleaning pipeline
│   ├── feature_engineering.py        # reusable feature engineering
│   └── train_model.py                # trains, compares, and saves the model
├── prediction/
│   └── predictor.py                  # orchestrates Layer 1 -> Layer 2
├── database/
│   ├── normalization.py              # brand/model text normalization
│   └── phone_database.py             # exact + fuzzy lookup against the CSV
├── app/
│   └── main.py                       # CLI entry point (Raspberry Pi facing)
├── analysis/
│   └── eda_and_analysis.py           # EDA charts (run on a dev machine)
├── tests/
│   └── test_system.py                # pytest suite
├── requirements.txt
└── README.md
```

Note: `preprocessing_pipeline.pkl` is not a separate file -- scikit-learn's
`Pipeline` bundles the `ColumnTransformer` (scaling + one-hot encoding)
and the regressor together, so `charging_watt_model.pkl` already contains
both. This keeps deployment to one artifact instead of two that could get
out of sync.

## 3. Dataset

758 rows, 27 columns, one row per phone. Key columns:

| Column | Meaning |
|---|---|
| `smartphone_brand`, `model` | Identity (used for Layer 1 lookup) |
| `price_inr`, `rating_score` | Price and an aggregate review score |
| `processor_name/brand`, `core_count`, `clock_speed_ghz` | CPU specs |
| `ram_gb`, `storage_gb` | Memory |
| `has_5g`, `has_nfc`, `has_ir_blaster` | Connectivity flags |
| `display_inches`, `res_width_px`, `res_height_px`, `refresh_rate_hz` | Display |
| `battery_mah`, `fast_charging` | Battery |
| `charging_watt` | **Target**: maximum charging wattage |
| `rear/front_camera_*` | Camera specs |
| `os_name`, `memory_card_supported/type` | OS and expandable storage |

**Target variable interpretation:** `charging_watt` behaves as the
*maximum supported charging power* (the number a manufacturer advertises
as the phone's fast-charging ceiling, e.g. "67W fast charging"), not the
wattage of a specific bundled charger or the wattage measured in a real
charging session. Values cluster tightly around common industry charger
steps (10, 15, 18, 20, 25, 27, 33, 45, 65, 67, 80, 90, 100, 120, 125W),
which is consistent with manufacturer-rated maximums rather than
continuously variable measured values.

### Data quality findings

- **No missing values** in most columns; `front_camera_main_mp` has 5
  missing values (phones with no front camera) and
  `memory_card_supported`/`memory_card_type` have 207 missing values
  (card slot not present/specified).
- **No fully duplicated rows** and **no duplicate (brand, model) pairs**
  in the current dataset.
- **No obviously invalid values** were found (no negative prices/battery,
  no non-positive charging_watt). Some values look extreme but are real:
  a rugged phone with a 21,200 mAh battery and 120W charging (Ulefone
  Armor 29 Pro 5G — rugged phones do ship with very large batteries and
  fast charging), several 16–24GB RAM and 1–2TB storage flagship
  variants, and a handful of very low-resolution budget/feature-style
  Android phones. None were removed.
- **Target distribution** is right-skewed (skew ≈ 0.77) — most phones
  cluster in the 15–45W range, with a long tail of flagship phones up to
  125W. This reflects genuine market structure (budget phones vastly
  outnumber 100W+ flagships), so it was **not forced into a normal
  distribution**; tree-based models handle this skew natively.

Full charts are generated by `analysis/eda_and_analysis.py` into
`analysis/output/` (target distribution, correlation heatmap, battery/
RAM/refresh-rate/price/clock-speed vs. wattage, and per-brand wattage
distribution).

### Correlation with charging_watt (numeric features)

`front_camera_main_mp` (0.64), `res_height_px` (0.62), `ram_gb` (0.59),
`rating_score` (0.56), `refresh_rate_hz` (0.48), `battery_mah` (0.45) are
the strongest linear correlates — all consistent with the real-world
pattern that higher-tier phones tend to ship both better cameras/screens
*and* faster charging, rather than any single spec directly causing fast
charging.

## 4. Cleaning & Feature Engineering

See `training/data_cleaning.py` and `training/feature_engineering.py`
for full logic and inline justification. Summary:

- Numeric coercion strips unit suffixes defensively (`"8 GB"→8`, in case
  future dataset updates reintroduce them); brand/processor/OS text is
  lowercased and trimmed.
- Missing `front_camera_main_mp` → filled with 0 (factually "no front
  camera", not an unknown to impute). Missing `memory_card_*` → filled
  with `False`/`"none"`.
- Duplicate rows dropped; duplicate (brand, model) with conflicting
  `charging_watt` resolved by majority vote — identically in both the
  database layer and the training pipeline, so the two layers can never
  disagree about the same phone.
- No outlier removal (see above) — only physically impossible values
  (`charging_watt <= 0`) would be dropped, and none exist currently.
- Engineered features: `total_pixels`, `pixels_per_inch`,
  `battery_per_inch`, `ram_per_core`, `performance_score`
  (core_count × clock_speed), and `device_tier` (price-based bucket:
  budget/midrange/upper_midrange/flagship). All are computable for a
  brand-new, never-seen phone from specs alone — **no feature uses
  information that wouldn't be available at prediction time**, avoiding
  data leakage.
- Categorical features (`smartphone_brand`, `processor_brand`, `os_name`,
  `device_tier`) are one-hot encoded with `handle_unknown="ignore"`
  inside the sklearn `Pipeline`, so a brand-new brand/processor at
  inference time is encoded as all-zeros instead of crashing.

## 5. Model Selection & Evaluation

`training/train_model.py` splits data with a **grouped** train/val/test
split (70/15/15) keyed on normalized (brand, model) — so that RAM/storage
variants of the same physical phone (e.g. "Redmi Note 14 Pro (8GB+256GB)"
vs. "(12GB+512GB)") never appear in both train and test, which would
otherwise leak information and inflate validation scores.

Seven candidates were trained and compared on the validation set:

| Model | MAE (W) | RMSE (W) | R² | Train time (s) | Predict (ms/row) |
|---|---|---|---|---|---|
| Mean baseline | 23.10 | 29.46 | -0.02 | 0.01 | 0.06 |
| Linear Regression | 11.59 | 14.61 | 0.75 | 0.01 | 0.05 |
| Ridge | 11.61 | 14.48 | 0.75 | 0.01 | 0.06 |
| Random Forest | 9.33 | 13.29 | 0.79 | 0.83 | 0.24 |
| **Extra Trees (selected)** | **9.10** | 13.56 | 0.78 | 0.64 | 0.23 |
| Gradient Boosting | 9.97 | 13.38 | 0.79 | 0.30 | 0.06 |
| Hist Gradient Boosting | 10.05 | 14.26 | 0.76 | 0.31 | 0.10 |

**Extra Trees Regressor** was selected: best validation MAE, a small
model (~a few MB), sub-millisecond-per-row inference (fine for a
Raspberry Pi), robust to the skewed target without needing a log
transform, and it handles the mix of numeric/categorical/boolean
features and unseen brands well via the shared preprocessing pipeline.

On the **held-out test set** (never used for model selection), the final
refit model achieved:

```
MAE:      6.06 W
RMSE:    10.04 W
R²:       0.87
MedianAE: 1.84 W
```

i.e. for a typical unknown phone, the predicted wattage is off by about
6W on average (and the *median* error is under 2W — most predictions are
very close, with a smaller number of harder cases pulling the mean up).
Exact numbers will shift slightly on retraining/dataset updates; see
`models/model_metadata.json` for the numbers from the most recent run,
which also records the full comparison table.

After model selection and test evaluation, the winning architecture is
refit one final time on **all** available data before being saved, so
the deployed model benefits from every known phone (standard practice
once evaluation is complete — the held-out test metrics above remain a
valid estimate of real-world accuracy).

## 6. How the Two Layers Connect (and why no leakage between them)

Both layers read from the same `data/smartphone_dataset.csv`, but:

- **Layer 1 always wins.** If `database/phone_database.py` finds a
  reliable match (exact normalized match, or a same-brand fuzzy match
  above a 92% similarity threshold), that verified value is returned
  immediately and the ML model is never invoked.
- **Layer 2 only runs on a miss.** The ML model was trained on the full
  dataset (after model selection used a grouped hold-out split), so
  it *has* implicitly "seen" every known phone during training — but
  that's fine, because Layer 1 intercepts every known phone before the
  ML model would ever be asked to predict on it. The ML model is only
  ever exercised, in production, on phones it did not encounter as
  training rows for the *specific query* being asked.
- Duplicate/conflicting rows are resolved identically in both layers
  (majority-vote), so the two layers can never disagree.

## 7. Running the System

### Install

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

### Train (run once, or whenever the dataset is updated)

```bash
python -m training.train_model
```

This prints the model comparison table and test metrics, and writes
`models/charging_watt_model.pkl` + `models/model_metadata.json`.

### Predict

```bash
# Known phone
python -m app.main --brand Xiaomi --model "Redmi Note 14 SE 5G"

# Unknown phone — provide as many specs as available for a better estimate
python -m app.main --brand NewBrand --model "NewPhone X1" \
    --ram_gb 12 --battery_mah 5000 --display_inches 6.7 \
    --refresh_rate_hz 120 --has_5g true --processor_brand snapdragon \
    --price_inr 35000

# Interactive mode
python -m app.main
```

Or from Python:

```python
from prediction.predictor import ChargingWattPredictor

predictor = ChargingWattPredictor()
result = predictor.predict({"smartphone_brand": "Xiaomi", "model": "Redmi Note 14 SE 5G"})
print(result.format())
# Phone: Xiaomi Redmi Note 14 SE 5G
# Maximum Charging Power: 45W
# Source: Verified Database Match
```

### FastAPI backend (deployed on Render)

This is the backend the Flutter frontend actually talks to.

```bash
# Local development
uvicorn app.api:app --reload --port 8000
```

Then open **http://localhost:8000/docs** for interactive Swagger docs, or point the
Flutter app's `ApiConfig.baseUrl` at `http://localhost:8000` (see the frontend README).

**Endpoints:**

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/predict` | POST | Runs the two-layer predictor, returns `{brand, model, charging_watt, source, note}` |
| `/api/health` | GET | Health check (used by Render and by the Flutter app's optional connectivity check) |
| `/api/status` | GET | Placeholder for a future live hardware readout — currently returns 501 |
| `/docs` | GET | Auto-generated Swagger UI |

#### Deploying to Render

1. Push this `backend/` folder to a GitHub repo (or the repo root, if it's the only service).
2. In Render: **New -> Web Service**, connect the repo.
3. Render will pick up `render.yaml` automatically if it's at the repo root, or set manually:
   - **Build command**: `pip install -r requirements.txt`
   - **Start command**: `uvicorn app.api:app --host 0.0.0.0 --port $PORT`
4. Once deployed, copy the Render URL (e.g. `https://charging-wattage-predictor-api.onrender.com`)
   into the Flutter app's `ApiConfig.baseUrl` when you're ready to switch off localhost.
5. **Before going further than local testing**, tighten `allow_origins` in `app/api.py`
   from `["*"]` to your actual deployed frontend domain(s) — it's left open for now
   since everything's local.

Note: Render's free tier spins down after inactivity, so the first request after a
period of idleness can take 30-60s while it wakes back up — the Flutter client's
10-second timeout may need lengthening for that tier specifically.

### Web UI

A lightweight local web interface is included (`app/web.py`), built on
top of the same `ChargingWattPredictor` used by the CLI — no duplicated
prediction logic.

```bash
python -m app.web
```

Then open **http://localhost:5000** in a browser (or, if running on a
Raspberry Pi, **http://<pi-ip-address>:5000** from any device on the
same network — the server binds to `0.0.0.0` so it's reachable from
other machines by default).

The page has a brand/model form, an optional "Add specs" section for the
ML fallback, and shows the result with a source badge (verified database
vs. ML prediction) and a wattage gauge. It calls a small JSON API
(`POST /api/predict`) that you can also hit directly, e.g.:

```bash
curl -X POST http://localhost:5000/api/predict \
  -H "Content-Type: application/json" \
  -d '{"smartphone_brand": "Xiaomi", "model": "Redmi Note 14 SE 5G"}'
```

Note: this uses Flask's built-in development server, which is fine for
personal/local use on a Pi. For anything exposed beyond your local
network, put it behind a production WSGI server (e.g. gunicorn) instead.

### Run tests

```bash
python -m pytest tests/test_system.py -v
```

### Run EDA (produces charts in `analysis/output/`)

```bash
python -m analysis.eda_and_analysis
```

## 8. Adding New Phones / Retraining

1. Append new rows to `data/smartphone_dataset.csv` (same column
   schema). No code changes are needed — the database lookup
   (`PhoneDatabase.from_csv`) picks up new rows automatically the next
   time the app starts.
2. Re-run training to let the ML fallback learn from the new phones too:
   ```bash
   python -m training.train_model
   ```
3. Copy the updated `models/charging_watt_model.pkl` (and
   `model_metadata.json`) to the Raspberry Pi.

```
New Dataset → Cleaning → EDA → Feature Engineering → Retraining → Evaluation → New Model Saved
```

All of the above steps are already encapsulated in the reusable
`training/data_cleaning.py`, `training/feature_engineering.py`, and
`training/train_model.py` modules — updating the dataset never requires
rewriting pipeline code.

## 9. Deploying to Raspberry Pi

- The Pi only needs: `pandas`, `numpy`, `scikit-learn`, `joblib` (the
  "core" section of `requirements.txt`) — **not** matplotlib/seaborn/
  pytest, which are training/analysis-only.
- Copy `data/smartphone_dataset.csv` (for Layer 1 lookup) and
  `models/charging_watt_model.pkl` (for Layer 2) to the Pi; run
  `app/main.py` there.
- The Extra Trees model is a few MB and predicts in well under a
  millisecond per row — negligible on Pi-class hardware.
- All heavy work (training, EDA, model comparison) is meant to run on a
  development machine; the Pi only ever loads the pickled pipeline and
  does inference.

## 10. Limitations & Expected Accuracy

- Test-set MAE ≈ 6W / median ≈ 2W (see §5) — treat ML predictions as
  *estimates*, not verified specs. Always prefer a database match.
- The dataset (758 phones, mostly Indian market listings) may
  under-represent some regions/brands; predictions for very unusual
  or niche phones (or entirely new charging technologies) will be
  less reliable.
- `rating_score` is an aggregate review score, not a hardware spec — it
  correlates with charging_watt likely because both track overall phone
  "tier," not because rating causes charging speed. It's included as an
  optional input, but predictions relying heavily on it (with everything
  else defaulted) should be treated with extra caution.
- If a caller supplies very few specs (< ~15% of the fields the model
  uses), the system deliberately refuses to guess and asks for more
  information instead of returning an unreliable number.
- Fuzzy matching in Layer 1 is restricted to the same normalized brand
  and a 92% similarity threshold, to avoid false-positive matches across
  similarly-named models from different brands.

## 11. Retraining Checklist

- [ ] New rows appended to `data/smartphone_dataset.csv`
- [ ] `python -m training.train_model` run successfully
- [ ] `models/model_metadata.json` reviewed for regressions in MAE/R²
- [ ] `python -m pytest tests/test_system.py -v` passes
- [ ] Updated `models/charging_watt_model.pkl` deployed to the Pi
