/// Successful prediction response.
///
/// Assumed FastAPI response shape:
/// ```json
/// {
///   "brand": "Xiaomi",
///   "model": "Redmi Note 14 SE 5G",
///   "charging_watt": 45.0,
///   "source": "Verified Database Match",
///   "note": null
/// }
/// ```
/// If your backend's field names differ, this is the only place to adjust.
class PredictionResult {
  final String brand;
  final String model;
  final double chargingWatt;
  final String source;
  final String? note;

  const PredictionResult({
    required this.brand,
    required this.model,
    required this.chargingWatt,
    required this.source,
    this.note,
  });

  bool get isVerified => source.toLowerCase().contains("database");

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      brand: json["brand"] as String? ?? "",
      model: json["model"] as String? ?? "",
      chargingWatt: (json["charging_watt"] as num).toDouble(),
      source: json["source"] as String? ?? "Unknown",
      note: json["note"] as String?,
    );
  }
}

/// Optional: live status readout, if the backend exposes actual measured
/// current from the ESP32/Arduino control loop. Safe to leave unused if
/// your backend doesn't have this endpoint.
class ChargingStatus {
  final double predictedWatt;
  final double? measuredWatt;
  final String status; // e.g. "OK" or "FAULT"

  const ChargingStatus({
    required this.predictedWatt,
    this.measuredWatt,
    required this.status,
  });

  factory ChargingStatus.fromJson(Map<String, dynamic> json) {
    return ChargingStatus(
      predictedWatt: (json["predicted_watt"] as num).toDouble(),
      measuredWatt: (json["measured_watt"] as num?)?.toDouble(),
      status: json["status"] as String? ?? "UNKNOWN",
    );
  }
}

/// Thrown by [PredictionApiService] for any non-2xx response or network
/// failure, with a message already suitable for display in the UI.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
