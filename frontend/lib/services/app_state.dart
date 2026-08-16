import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";

/// Thin ChangeNotifier around FirebaseAuth's current session. The splash
/// screen reads [isAuthenticated] synchronously on first frame to decide
/// whether to auto-navigate to the dashboard or wait for the user to tap
/// through the marketing CTA into the auth screen.
class AppState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final _subscription = _auth.authStateChanges().listen(_onAuthChanged);

  User? _user;
  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;

  AppState() {
    _user = _auth.currentUser;
    // Force subscription creation.
    // ignore: unnecessary_statements
    _subscription;
  }

  void _onAuthChanged(User? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
