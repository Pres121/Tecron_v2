import "package:flutter/material.dart";

import "../services/app_state.dart";
import "../services/user_profile_service.dart";
import "../theme/app_theme.dart";
import "splash_screen.dart";

class SettingsScreen extends StatefulWidget {
  final AppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = UserProfileService();
  final _displayNameCtrl = TextEditingController();

  bool _notificationsEnabled = true;
  bool _autoConfirmCharging = false;
  bool _isLoading = true;
  bool _isSaving = false;

  String get _uid => widget.appState.currentUser!.uid;
  String get _email => widget.appState.currentUser?.email ?? "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.fetchProfile(_uid);
    if (!mounted) return;
    setState(() {
      _displayNameCtrl.text = profile.displayName;
      _notificationsEnabled = profile.notificationsEnabled;
      _autoConfirmCharging = profile.autoConfirmCharging;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    await _profileService.saveProfile(
      _uid,
      UserProfile(
        displayName: _displayNameCtrl.text.trim(),
        notificationsEnabled: _notificationsEnabled,
        autoConfirmCharging: _autoConfirmCharging,
        defaultChargeLimitOverride: 0,
      ),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings saved")),
    );
  }

  Future<void> _signOut() async {
    await widget.appState.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SplashScreen(appState: widget.appState)),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Settings",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Manage your account and app preferences.",
              style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            _sectionCard(
              title: "Profile",
              children: [
                Text(_email, style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                const SizedBox(height: 12),
                TextField(
                  controller: _displayNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Display name",
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textFaint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: "Preferences",
              children: [
                _switchTile(
                  title: "Notifications",
                  subtitle: "Get notified when charging starts or stops",
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const Divider(height: 24, color: AppColors.surfaceBorder),
                _switchTile(
                  title: "Auto-confirm charging",
                  subtitle: "Skip the confirmation step when starting a charge",
                  value: _autoConfirmCharging,
                  onChanged: (v) => setState(() => _autoConfirmCharging = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.textPrimary),
                      )
                    : const Text("Save changes"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                label: const Text("Sign out", style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
      ],
    );
  }
}
