"""
api.py
------
FastAPI service exposing the two-layer predictor over REST. This is the
backend meant for Render deployment — the Flask app in web.py and the CLI
in main.py still work locally but aren't what gets deployed.

Run locally:
    uvicorn app.api:app --reload --port 8000

Then:
    http://localhost:8000/docs   -> interactive Swagger UI
"""

import sys
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

sys.path.append(str(Path(__file__).resolve().parents[1]))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from prediction.predictor import ChargingWattPredictor, ValidationError

# Loaded once at startup (not per-request) via the lifespan handler below —
# same reasoning as the Flask version: the database + model are read from
# disk once and reused for every request.
predictor: Optional[ChargingWattPredictor] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global predictor
    predictor = ChargingWattPredictor()
    yield
    predictor = None


app = FastAPI(
    title="Charging Wattage Predictor API",
    description="Two-layer prediction: verified database lookup, then ML fallback.",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS: open for now since the Flutter app runs on localhost during
# development (and Flutter mobile builds don't send an Origin header at
# all, so CORS is a web-only concern anyway). Tighten allow_origins to
# your actual deployed frontend domain(s) before shipping this to Render.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class PredictRequest(BaseModel):
    """Mirrors PhoneSpec.toJson() on the Flutter side field-for-field."""

    smartphone_brand: str
    model: str

    price_inr: Optional[float] = None
    rating_score: Optional[float] = None
    processor_brand: Optional[str] = None
    core_count: Optional[int] = None
    clock_speed_ghz: Optional[float] = None
    ram_gb: Optional[float] = None
    storage_gb: Optional[float] = None
    has_5g: Optional[bool] = None
    has_nfc: Optional[bool] = None
    has_ir_blaster: Optional[bool] = None
    display_inches: Optional[float] = None
    refresh_rate_hz: Optional[int] = None
    battery_mah: Optional[float] = None
    fast_charging: Optional[bool] = None


class PredictResponse(BaseModel):
    """Mirrors PredictionResult.fromJson() on the Flutter side field-for-field."""

    brand: str
    model: str
    charging_watt: float
    source: str
    note: Optional[str] = None


@app.get("/")
def root():
    return {"service": "charging-wattage-predictor", "docs": "/docs"}


@app.get("/api/health")
def health():
    return {"status": "ok", "database_loaded": predictor is not None}


@app.post("/api/predict", response_model=PredictResponse)
def predict(request: PredictRequest):
    if predictor is None:
        raise HTTPException(status_code=503, detail="Predictor is still starting up.")

    # exclude_none so unset optional fields don't override the predictor's
    # own defaults (same behavior as the Flutter client omitting null fields).
    spec = request.model_dump(exclude_none=True)

    try:
        result = predictor.predict(spec)
    except ValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Prediction failed unexpectedly.")

    return PredictResponse(
        brand=result.brand.title(),
        model=result.model,
        charging_watt=result.charging_watt,
        source=result.source,
        note=result.confidence_note,
    )


@app.get("/api/status")
def status():
    """
    Placeholder for a future live "predicted vs measured" readout if this
    backend ever relays real-time data from hardware (ESP32/Arduino).
    Not wired to anything yet -- returns 501 so the Flutter client's
    fetchStatus() cleanly gets nothing back instead of a confusing 200.
    """
    raise HTTPException(status_code=501, detail="Live status not implemented yet.")
