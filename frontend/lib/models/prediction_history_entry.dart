import "package:cloud_firestore/cloud_firestore.dart";

/// A single past prediction, saved to Firestore under
/// users/{uid}/predictions/{docId} after a successful API call.
class PredictionHistoryEntry {
  final String? id;
  final String brand;
  final String model;
  final double chargingWatt;
  final String source;
  final DateTime createdAt;

  const PredictionHistoryEntry({
    this.id,
    required this.brand,
    required this.model,
    required this.chargingWatt,
    required this.source,
    required this.createdAt,
  });

  bool get isVerified => source.toLowerCase().contains("database");

  Map<String, dynamic> toMap() {
    return {
      "brand": brand,
      "model": model,
      "charging_watt": chargingWatt,
      "source": source,
      "created_at": Timestamp.fromDate(createdAt),
    };
  }

  factory PredictionHistoryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PredictionHistoryEntry(
      id: doc.id,
      brand: data["brand"] as String? ?? "",
      model: data["model"] as String? ?? "",
      chargingWatt: (data["charging_watt"] as num).toDouble(),
      source: data["source"] as String? ?? "",
      createdAt: (data["created_at"] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
