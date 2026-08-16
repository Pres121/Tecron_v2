import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

import "../models/phone_spec.dart";
import "../models/prediction_history_entry.dart";
import "../models/prediction_result.dart";
import "../services/auth_service.dart";
import "../services/bluetooth_service.dart";
import "../services/firestore_service.dart";
import "../services/prediction_api_service.dart";
import "../services/prediction_state.dart";
import "../theme/app_theme.dart";
import "../widgets/phone_form.dart";
import "../widgets/source_badge.dart";
import "../widgets/wattage_gauge.dart";

/// Dashboard's Home tab: hero banner, the prediction form, the result,
/// and (once a prediction exists) a "Start charging" action that's only
/// enabled while a Tecron device is connected over Bluetooth.
///
/// No Scaffold/AppBar of its own -- this is one page inside DashboardScreen's
/// PageView, which owns the shared bottom nav.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _api = PredictionApiService();
  final _authService = AuthService();
  final _firestore = FirestoreService();
  final _bluetooth = BluetoothService.instance;

  bool _isLoading = false;
  bool _isCharging = false;
  String? _errorMessage;
  PredictionResult? _result;

  User? get _user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    _bluetooth.addListener(_onBluetoothChanged);
  }

  void _onBluetoothChanged() {
    if (!_bluetooth.isConnected && _isCharging) {
      setState(() => _isCharging = false);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bluetooth.removeListener(_onBluetoothChanged);
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

      // Share the latest result app-wide (the Connection tab's device
      // sees it as the charge limit to set) and persist to history.
      PredictionState.instance.update(result);

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

  Future<void> _toggleCharging(PredictionResult result) async {
    if (!_bluetooth.isConnected) return;

    if (!_isCharging) {
      await _bluetooth.sendCommand(
        "Set max wattage",
        result.chargingWatt % 1 == 0 ? result.chargingWatt.toStringAsFixed(0) : result.chargingWatt.toStringAsFixed(1),
      );
      await _bluetooth.sendCommand("Start charging", "true");
      setState(() => _isCharging = true);
    } else {
      await _bluetooth.sendCommand("Start charging", "false");
      setState(() => _isCharging = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isCharging ? "Charging started at ${result.chargingWatt.toStringAsFixed(0)}W" : "Charging stopped"),
        backgroundColor: _isCharging ? AppColors.primaryDark : AppColors.textSecondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(),
            const SizedBox(height: 12),
            // Circular start/stop charging button placed directly under the hero
            if (_result != null) Center(child: _circularChargingButton(_result!)),
            const SizedBox(height: 20),
            _header(),
            const SizedBox(height: 24),
            if (_errorMessage != null) _errorBanner(_errorMessage!),
            PhoneForm(isLoading: _isLoading, onSubmit: _handleSubmit),
            const SizedBox(height: 20),
            if (_result != null) ...[
              _resultCard(_result!),
              const SizedBox(height: 16),
              _chargingAction(_result!),
            ],
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
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 16),
          const Text(
            "Charge every phone at its true limit",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            "Predict, then charge — connect your Tecron device to act on it instantly.",
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Maximum charging wattage",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
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
            child: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.error, height: 1.5)),
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
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                child: Text(result.note!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chargingAction(PredictionResult result) {
    final isConnected = _bluetooth.isConnected;

    // Keep a compact status card instead; the circular action is now above
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
              size: 18,
              color: isConnected ? AppColors.primary : AppColors.textFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isConnected
                    ? "Ready to charge at ${result.chargingWatt.toStringAsFixed(0)}W"
                    : "Connect a device on the Connection tab first",
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Text(_isCharging ? "Charging" : "Idle", style: TextStyle(color: _isCharging ? AppColors.error : AppColors.textFaint)),
          ],
        ),
      ),
    );
  }

  Widget _circularChargingButton(PredictionResult result) {
    final isConnected = _bluetooth.isConnected;
    final label = _isCharging ? "Stop" : "Start";
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: Column(
        children: [
          GestureDetector(
            onTap: isConnected ? () => _toggleCharging(result) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: isConnected
                    ? (_isCharging ? AppColors.error : AppColors.primary)
                    : AppColors.neutralSoft,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withAlpha(isConnected ? 40 : 15), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isCharging ? Icons.power_settings_new_rounded : Icons.bolt_rounded,
                    key: ValueKey<bool>(_isCharging),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
