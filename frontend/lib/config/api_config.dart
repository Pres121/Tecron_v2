/// Central place to point this app at your backend.
///
/// If your actual FastAPI routes/response shape differ from what's assumed
/// here, this is the only file (plus prediction_api_service.dart for
/// response parsing) you should need to touch.
class ApiConfig {
  /// TODO: switch this to your Render URL once deployed, e.g.
  /// "https://charging-wattage-predictor-api.onrender.com" -- this is the
  /// only line that needs to change to go from local to production.
  ///
  /// For now (local FastAPI via `uvicorn app.api:app --reload --port 8000`):
  /// - Web (flutter run -d chrome): "http://localhost:8000" (current default)
  /// - Android emulator: "http://10.0.2.2:8000" (emulator's alias for the host)
  /// - iOS simulator: "http://localhost:8000"
  /// - Physical device on the same WiFi: your machine's LAN IP, e.g.
  ///   "http://192.168.1.50:8000"
  static const String baseUrl = "http://localhost:8000";

  /// FastAPI route for a prediction request: POST {baseUrl}/api/predict
  static const String predictPath = "/api/predict";

  /// Health-check endpoint: GET {baseUrl}/api/health
  static const String healthPath = "/api/health";

  /// Optional: live measured-wattage readout, if the backend exposes one
  /// (e.g. relaying status from hardware). Currently returns 501 on the
  /// backend -- safe to ignore until that's implemented.
  static const String statusPath = "/api/status";

  static const Duration requestTimeout = Duration(seconds: 10);
}
