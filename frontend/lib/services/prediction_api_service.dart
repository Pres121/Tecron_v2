import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;

import "../config/api_config.dart";
import "../models/phone_spec.dart";
import "../models/prediction_result.dart";

/// Thin REST client wrapping the FastAPI backend. Every method throws
/// [ApiException] with a message already safe to show directly in the UI —
/// screens shouldn't need to know about HTTP status codes or JSON shapes.
class PredictionApiService {
  final http.Client _client;
  final String baseUrl;

  PredictionApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<PredictionResult> predict(PhoneSpec spec) async {
    final uri = Uri.parse("$baseUrl${ApiConfig.predictPath}");
    late http.Response response;

    try {
      response = await _client
          .post(
            uri,
            headers: const {"Content-Type": "application/json"},
            body: jsonEncode(spec.toJson()),
          )
          .timeout(ApiConfig.requestTimeout);
    } on SocketException {
      throw const ApiException(
        "Can't reach the server. Check that the backend is running and "
        "that the base URL in api_config.dart is correct for this device.",
      );
    } on http.ClientException {
      throw const ApiException("Network error while contacting the server.");
    } catch (_) {
      throw const ApiException("Request timed out. Please try again.");
    }

    return _handlePredictResponse(response);
  }

  PredictionResult _handlePredictResponse(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        "Server returned an unreadable response (status ${response.statusCode}).",
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return PredictionResult.fromJson(body);
      } catch (_) {
        throw const ApiException(
          "Server response didn't match the expected format. If your "
          "FastAPI response fields differ from brand/model/charging_watt/"
          "source/note, update PredictionResult.fromJson().",
        );
      }
    }

    throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode);
  }

  /// FastAPI's default error shapes:
  ///   - HTTPException(detail="some string")            -> {"detail": "some string"}
  ///   - Pydantic validation error (422)                  -> {"detail": [{"loc":[...],"msg":"...","type":"..."}]}
  /// This handles both so validation errors show something readable
  /// instead of a raw list dump.
  String _extractErrorMessage(Map<String, dynamic> body) {
    final detail = body["detail"];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final messages = detail
          .map((e) => e is Map && e["msg"] != null ? e["msg"].toString() : e.toString())
          .join("; ");
      return messages;
    }
    return "Request failed.";
  }

  /// Optional connectivity check for a "backend reachable" indicator.
  /// Returns false on any error rather than throwing, since callers
  /// typically just want a boolean for a status dot in the UI.
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse("$baseUrl${ApiConfig.healthPath}");
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Optional: live measured wattage, if the backend exposes it.
  Future<ChargingStatus?> fetchStatus() async {
    try {
      final uri = Uri.parse("$baseUrl${ApiConfig.statusPath}");
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      return ChargingStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
