import "package:firebase_auth/firebase_auth.dart";

/// Thin wrapper around FirebaseAuth. Screens depend on this, never on
/// FirebaseAuth directly, so the auth provider could be swapped later
/// without touching UI code.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes — used by AppState to track whether
  /// someone is currently signed in.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Translates Firebase's error codes into messages safe to show directly
  /// in the UI, instead of leaking codes like "auth/invalid-credential".
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "That email address doesn't look right.";
      case "user-disabled":
        return "This account has been disabled.";
      case "user-not-found":
      case "wrong-password":
      case "invalid-credential":
        return "Incorrect email or password.";
      case "email-already-in-use":
        return "An account already exists for that email.";
      case "weak-password":
        return "Choose a stronger password (at least 6 characters).";
      case "network-request-failed":
        return "Network error. Check your connection and try again.";
      case "too-many-requests":
        return "Too many attempts. Please wait a moment and try again.";
      default:
        return e.message ?? "Something went wrong. Please try again.";
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
