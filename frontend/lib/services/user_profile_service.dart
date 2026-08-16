import "package:cloud_firestore/cloud_firestore.dart";

/// A user's editable profile fields + app preferences, stored at
/// users/{uid} (a single document, separate from the
/// users/{uid}/predictions subcollection used for history).
class UserProfile {
  final String displayName;
  final bool notificationsEnabled;
  final bool autoConfirmCharging;
  final double defaultChargeLimitOverride; // 0 = no override, use prediction as-is

  const UserProfile({
    required this.displayName,
    required this.notificationsEnabled,
    required this.autoConfirmCharging,
    required this.defaultChargeLimitOverride,
  });

  static const empty = UserProfile(
    displayName: "",
    notificationsEnabled: true,
    autoConfirmCharging: false,
    defaultChargeLimitOverride: 0,
  );

  UserProfile copyWith({
    String? displayName,
    bool? notificationsEnabled,
    bool? autoConfirmCharging,
    double? defaultChargeLimitOverride,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoConfirmCharging: autoConfirmCharging ?? this.autoConfirmCharging,
      defaultChargeLimitOverride: defaultChargeLimitOverride ?? this.defaultChargeLimitOverride,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "display_name": displayName,
      "notifications_enabled": notificationsEnabled,
      "auto_confirm_charging": autoConfirmCharging,
      "default_charge_limit_override": defaultChargeLimitOverride,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) return empty;
    return UserProfile(
      displayName: data["display_name"] as String? ?? "",
      notificationsEnabled: data["notifications_enabled"] as bool? ?? true,
      autoConfirmCharging: data["auto_confirm_charging"] as bool? ?? false,
      defaultChargeLimitOverride: (data["default_charge_limit_override"] as num?)?.toDouble() ?? 0,
    );
  }
}

class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) => _db.collection("users").doc(uid);

  Future<UserProfile> fetchProfile(String uid) async {
    final doc = await _profileRef(uid).get();
    return UserProfile.fromMap(doc.data());
  }

  Stream<UserProfile> watchProfile(String uid) {
    return _profileRef(uid).snapshots().map((doc) => UserProfile.fromMap(doc.data()));
  }

  Future<void> saveProfile(String uid, UserProfile profile) async {
    await _profileRef(uid).set(profile.toMap(), SetOptions(merge: true));
  }
}
