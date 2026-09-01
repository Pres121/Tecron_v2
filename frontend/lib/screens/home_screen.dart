import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../models/phone_spec.dart";
import "../models/prediction_history_entry.dart";
import "../models/prediction_result.dart";
import "../services/auth_service.dart";
import "../services/firestore_service.dart";
import "../services/prediction_api_service.dart";
import "../theme/app_theme.dart";
import "../widgets/phone_form.dart";
import "../widgets/source_badge.dart";
import "../widgets/wattage_gauge.dart";
import "history_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = PredictionApiService();
  final _authService = AuthService();
  final _firestore = FirestoreService();

  bool _isLoading = false;
  String? _errorMessage;
  PredictionResult? _result;

  User? get _user => _authService.currentUser;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(PhoneSpec spec) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _api.predict(spec);
      setState(() => _result = result);

      // Save to the signed-in user's Firestore history. Non-fatal if this
      // fails (e.g. offline) -- the prediction itself already succeeded and
      // is shown to the user regardless.
      final uid = _user?.uid;
      if (uid != null) {
        _firestore
            .savePrediction(
              uid,
              PredictionHistoryEntry(
                brand: result.brand,
                model: result.model,
                chargingWatt: result.chargingWatt,
                source: result.source,
                createdAt: DateTime.now(),
              ),
            )
            .catchError((_) {});
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    // AuthGate's stream listener handles navigation back to the login screen.
  }

  void _openHistory() {
    final uid = _user?.uid;
    if (uid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topBar(),
                const SizedBox(height: 28),
                _header(),
                const SizedBox(height: 24),
                if (_errorMessage != null) _errorBanner(_errorMessage!),
                PhoneForm(isLoading: _isLoading, onSubmit: _handleSubmit),
                const SizedBox(height: 20),
                if (_result != null) _resultCard(_result!),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    "Verified database lookup, with a machine learning fallback",
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.bolt_rounded, color: AppColors.textPrimary, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          "Tecron",
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const Spacer(),
        IconButton(
          tooltip: "History",
          icon: const Icon(Icons.history_rounded, color: AppColors.textSecondary),
          onPressed: _openHistory,
        ),
        IconButton(
          tooltip: "Sign out",
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          onPressed: _signOut,
        ),
      ],
    );
  }

  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Maximum charging wattage",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        SizedBox(height: 8),
        Text(
          "Enter a phone's brand and model to look it up. If it's not in the "
          "known database, add whatever specs you have and we'll estimate it.",
          style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13.5, color: AppColors.error, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(PredictionResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${result.brand} ${result.model}",
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            WattageGauge(watts: result.chargingWatt),
            const SizedBox(height: 16),
            SourceBadge(isVerified: result.isVerified),
            if (result.note != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.note!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
