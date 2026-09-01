import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

/// A compact, mobile-first authentication screen inspired by the reference's
/// spacious layout, rounded fields, and clear sign-in/sign-up hierarchy.
class AuthScreen extends StatefulWidget {
  final AppState appState;

  const AuthScreen({super.key, required this.appState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSignup = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isSignup) {
        await _auth.signUp(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      } else {
        await _auth.signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(appState: widget.appState)),
      );
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter your email address first.');
      return;
    }
    try {
      await _auth.sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  void _selectMode(bool signup) {
    setState(() {
      _isSignup = signup;
      _errorMessage = null;
    });
    _entranceController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignup ? 'Create your account' : 'Welcome back';
    final subtitle = _isSignup
        ? 'Use your email and password to start charging smarter.'
        : 'Sign in to view predictions and manage your Tecron device.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(0, 0.48, curve: Curves.easeOut),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _entrance(const _TecronMark(), delay: 0.02),
                    const SizedBox(height: 24),
                    _entrance(
                      Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
                          ),
                        ],
                      ),
                      delay: 0.1,
                    ),
                    const SizedBox(height: 26),
                    _entrance(_modeSelector(), delay: 0.18),
                    const SizedBox(height: 22),
                    if (_errorMessage != null) _errorBanner(_errorMessage!),
                    _entrance(_socialButtons(), delay: 0.25),
                    const SizedBox(height: 18),
                    _entrance(const _OrDivider(), delay: 0.3),
                    const SizedBox(height: 18),
                    _entrance(
                      _field(
                        controller: _emailCtrl,
                        label: 'Email address',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address' : null,
                      ),
                      delay: 0.36,
                    ),
                    const SizedBox(height: 14),
                    _entrance(
                      _field(
                        controller: _passwordCtrl,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                        validator: (value) => value == null || value.length < 6 ? 'Use at least 6 characters' : null,
                      ),
                      delay: 0.46,
                    ),
                    if (_isSignup) ...[
                      const SizedBox(height: 14),
                      _entrance(
                        _field(
                          controller: _confirmCtrl,
                          label: 'Confirm password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          validator: (value) => value != _passwordCtrl.text ? 'Passwords do not match' : null,
                        ),
                        delay: 0.54,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _entrance(_accountActions(), delay: _isSignup ? 0.62 : 0.54),
                    const SizedBox(height: 18),
                    _entrance(
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: const StadiumBorder(),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                                )
                              : Text(_isSignup ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      delay: _isSignup ? 0.7 : 0.64,
                    ),
                    const SizedBox(height: 20),
                    _entrance(_modePrompt(), delay: _isSignup ? 0.76 : 0.7),
                  ],
                ),
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

  Widget _entrance(Widget child, {required double delay}) {
    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(delay, 1, curve: Curves.easeOutBack),
    );
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: Interval(delay, 1, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.09), end: Offset.zero).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _modeButton('Sign in', !_isSignup, () => _selectMode(false))),
          Expanded(child: _modeButton('Sign up', _isSignup, () => _selectMode(true))),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: selected ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _socialButtons() {
    return Row(
      children: [
        Expanded(child: _socialButton('Google', Icons.g_mobiledata_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _socialButton('Apple', Icons.apple_rounded)),
      ],
    );
  }

  Widget _socialButton(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label sign-in is not configured yet.')),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.surfaceBorder),
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textFaint),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _accountActions() {
    if (_isSignup) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'By creating an account, you agree to the Terms and Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, height: 1.4),
        ),
      );
    }
    return Row(
      children: [
        Checkbox(value: _rememberMe, onChanged: (value) => setState(() => _rememberMe = value ?? false)),
        const Text('Remember me', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const Spacer(),
        TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
      ],
    );
  }

  Widget _modePrompt() {
    final prompt = _isSignup ? 'Already have an account?' : 'New to Tecron?';
    final action = _isSignup ? 'Sign in' : 'Create account';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        TextButton(onPressed: () => _selectMode(!_isSignup), child: Text(action)),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
    );
  }
}

class _TecronMark extends StatelessWidget {
  const _TecronMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 20)],
          ),
          child: const Icon(Icons.bolt_rounded, color: AppColors.textPrimary, size: 30),
        ),
        const SizedBox(height: 9),
        const Text('TECRON', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ],
    );
  }
}

/// Mirrors the splash screen's layered dark gradient and soft green glows,
/// so the transition from the welcome screen into authentication feels shared.
class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.35),
              radius: 1.2,
              colors: [Color(0xFF0F1419), Color(0xFF090B0F)],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.55),
          child: Container(
            width: 360,
            height: 360,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x4022C55E), Color(0x1022C55E), Colors.transparent],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0.85, 0.75),
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x2634D399), Color(0x0822C55E), Colors.transparent],
                stops: [0, 0.52, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.surfaceBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with email', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ),
        Expanded(child: Divider(color: AppColors.surfaceBorder)),
      ],
    );
  }
}
