import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../services/auth_service.dart";
import "../theme/app_theme.dart";
import "home_screen.dart";
import "login_screen.dart";

/// Listens to Firebase auth state and shows the login flow or the home
/// screen accordingly. This is what the splash screen navigates to —
/// it's the single source of truth for "is someone logged in".
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
