import "dart:ui" as ui;
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
  bool _isChargeCommandPending = false;
  String? _errorMessage;
  PredictionResult? _result;

  User? get _user => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    _bluetooth.addListener(_onBluetoothChanged);
  }

  // Small feature chips to add visual interest below the header
  Widget _featureRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          _featureTile(Icons.verified_rounded, "Verified DB"),
          const SizedBox(width: 10),
          _featureTile(Icons.speed_rounded, "Fast"),
          const SizedBox(width: 10),
          _featureTile(Icons.lock_rounded, "Private"),
        ],
      ),
    );
  }

  Widget _featureTile(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
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
        await _savePrediction(uid, result);
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrediction(String uid, PredictionResult result) async {
    final entry = PredictionHistoryEntry(
      brand: result.brand,
      model: result.model,
      chargingWatt: result.chargingWatt,
      source: result.source,
      createdAt: DateTime.now(),
    );

    try {
      final existing = await _firestore.getLatestPrediction(uid);
      if (!mounted) return;

      if (existing == null) {
        await _firestore.savePrediction(uid, entry);
        return;
      }

      final shouldReplace = await _confirmReplacement(existing, entry);
      if (shouldReplace == true && existing.id != null) {
        await _firestore.replacePrediction(uid, existing.id!, entry);
      }
    } catch (_) {
      // A prediction remains usable even when offline or Firestore is unavailable.
    }
  }

  Future<bool?> _confirmReplacement(
    PredictionHistoryEntry existing,
    PredictionHistoryEntry replacement,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Replace saved wattage?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You already have a saved charging limit. Replace it with this new prediction?',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 18),
            _wattageComparison('Current', existing.brand, existing.model, existing.chargingWatt, AppColors.textFaint),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.arrow_downward_rounded, color: AppColors.primary),
            ),
            _wattageComparison('New prediction', replacement.brand, replacement.model, replacement.chargingWatt, AppColors.primary),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep current')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Widget _wattageComparison(String label, String brand, String model, double watts, Color color) {
    final wattage = watts % 1 == 0 ? watts.toStringAsFixed(0) : watts.toStringAsFixed(1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 11)),
                const SizedBox(height: 3),
                Text('$brand $model', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text('$wattage W', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Future<void> _toggleCharging(PredictionResult result) async {
    if (!_bluetooth.isConnected || _isChargeCommandPending) return;
    setState(() => _isChargeCommandPending = true);

    try {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update charging. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isChargeCommandPending = false);
    }
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
            _chargingAction(_result),
            const SizedBox(height: 20),
            _header(),
            const SizedBox(height: 12),
            _featureRow(),
            const SizedBox(height: 12),
            if (_errorMessage != null) _errorBanner(_errorMessage!),
            PhoneForm(isLoading: _isLoading, onSubmit: _handleSubmit),
            const SizedBox(height: 20),
            if (_result != null) ...[
              _resultCard(_result!),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Stack(clipBehavior: Clip.hardEdge,
        children: [
          // Decorative rotated accent behind content
          Positioned(
            right: 12,
            top: -10,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 180,
                height: 160,
                  decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.textPrimary.withValues(alpha: 0.06), AppColors.textPrimary.withValues(alpha: 0.02)]),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Glass icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.bolt_rounded, color: AppColors.textPrimary, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Charge every phone at its true limit",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.15),
              ),
              const SizedBox(height: 8),
              Text(
                "Predict, then charge — connect your Tecron device to act on it instantly.",
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary.withValues(alpha: 0.92), height: 1.4),
              ),
              const SizedBox(height: 12),
              // Subtle tagline chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on_rounded, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text("Start Charging Smarter", style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Maximum charging wattage",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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

  Widget _chargingAction(PredictionResult? result) {
    final isConnected = _bluetooth.isConnected;
    final isReady = result != null && isConnected;
    final isActive = isReady && !_isChargeCommandPending;
    final headline = result == null
        ? 'Predict a max wattage to unlock charging'
        : isConnected
            ? 'Ready to charge at ${result.chargingWatt.toStringAsFixed(0)}W'
            : 'Connect a Tecron device to start charging';
    final buttonLabel = _isChargeCommandPending
        ? (_isCharging ? 'Stopping charging...' : 'Starting charging...')
        : result == null
            ? 'Predict a phone first'
            : !isConnected
                ? 'Connect device to start'
                : _isCharging
                    ? 'Stop charging'
                    : 'Start charging';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isCharging ? AppColors.primary : AppColors.surfaceBorder),
        boxShadow: _isCharging
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 10))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isReady ? AppColors.primary : AppColors.textFaint).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReady ? Icons.bolt_rounded : Icons.bluetooth_disabled_rounded,
                  color: isReady ? AppColors.primary : AppColors.textFaint,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(colors: _isCharging ? [AppColors.error, const Color(0xFFEF7777)] : [AppColors.primaryDark, AppColors.primary])
                    : null,
                color: isActive ? null : AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 7))] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isActive ? () => _toggleCharging(result) : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Row(
                      key: ValueKey(buttonLabel),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isChargeCommandPending)
                          const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                          )
                        else
                          Icon(_isCharging ? Icons.stop_circle_outlined : Icons.bolt_rounded, color: AppColors.textPrimary),
                        const SizedBox(width: 9),
                        Text(buttonLabel, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
