# Tecron — Smartphone Charging Wattage Predictor

Two-part project:

- **`backend/`** — Python. The trained ML predictor (database lookup + Extra Trees
  fallback), exposed as a FastAPI service, deployable to Render.
- **`frontend/`** — Flutter. The Tecron app: Firebase Auth for login, Firestore for
  saved prediction history, calling the FastAPI backend for the actual predictions.

## Quick start (local development)

**Terminal 1 — backend:**
```bash
cd backend
pip install -r requirements.txt
uvicorn app.api:app --reload --port 8000
```
Confirm it's up at http://localhost:8000/docs

**Terminal 2 — frontend:**
```bash
cd frontend
flutterfire configure   # one-time: connects this app to your Firebase project
flutter pub get
flutter run -d chrome
```

See `backend/README.md` and `frontend/README.md` for full details — dataset/model
info and Render deployment on the backend side; Firebase setup and Firestore security
rules on the frontend side.

## How a prediction flows through the whole system

1. User opens Tecron, signs in (Firebase Auth).
2. User enters a phone's brand/model (+ optional specs) in the form.
3. Flutter sends a `POST /api/predict` to the FastAPI backend.
4. Backend checks the known-phone database first (verified match), falls back to the
   ML model if the phone isn't found.
5. Backend returns `{brand, model, charging_watt, source, note}`.
6. Flutter displays the result and saves it to the user's Firestore history
   (`users/{uid}/predictions/...`).

## Moving from localhost to production

Two independent switches, in this order:

1. **Deploy the backend to Render** (see `backend/README.md`) — get a URL like
   `https://your-service.onrender.com`.
2. **Update `frontend/lib/config/api_config.dart`** — change `baseUrl` to that Render
   URL. That's the only line that needs to change on the frontend.
