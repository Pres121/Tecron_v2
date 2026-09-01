import "package:cloud_firestore/cloud_firestore.dart";

import "../models/prediction_history_entry.dart";

/// Stores each user's prediction history under:
///   users/{uid}/predictions/{autoId}
///
/// Per-user subcollections keep Firestore security rules simple (a user
/// can only ever read/write their own predictions) and avoid needing any
/// composite indexes for the common "my most recent predictions" query.
///
/// Suggested Firestore security rule to pair with this:
/// ```
/// match /users/{userId}/predictions/{predictionId} {
///   allow read, write: if request.auth != null && request.auth.uid == userId;
/// }
/// ```
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _predictionsRef(String uid) {
    return _db.collection("users").doc(uid).collection("predictions");
  }

  Future<void> savePrediction(String uid, PredictionHistoryEntry entry) async {
    await _predictionsRef(uid).add(entry.toMap());
  }

  /// Returns the user's current saved charging limit, if one exists.
  Future<PredictionHistoryEntry?> getLatestPrediction(String uid) async {
    final snapshot = await _predictionsRef(uid)
        .orderBy("created_at", descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PredictionHistoryEntry.fromDoc(snapshot.docs.first);
  }

  /// Replaces the current saved charging limit while preserving its document
  /// identity, so a repeat prediction does not create a duplicate entry.
  Future<void> replacePrediction(String uid, String entryId, PredictionHistoryEntry entry) async {
    await _predictionsRef(uid).doc(entryId).set(entry.toMap());
  }

  /// Live stream of a user's most recent predictions, newest first.
  Stream<List<PredictionHistoryEntry>> watchHistory(String uid, {int limit = 50}) {
    return _predictionsRef(uid)
        .orderBy("created_at", descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PredictionHistoryEntry.fromDoc).toList());
  }

  Future<void> deleteEntry(String uid, String entryId) async {
    await _predictionsRef(uid).doc(entryId).delete();
  }
}
