import "package:flutter/material.dart";

import "../services/app_state.dart";
import "../services/auth_service.dart";
import "dashboard_screen.dart";

const _bgColor = Color(0xFF090B0F);
const _cardColor = Color(0xFF14181D);
const _borderColor = Color(0x14FFFFFF);
const _green = Color(0xFF22C55E);
const _greenLight = Color(0xFF34D399);
const _textDim = Color(0xFFB8C1CC);
const _textFaint = Color(0xFF6B7580);

/// Combined login/signup screen, styled to match the splash screen's
/// dark, glassmorphism aesthetic. A segmented toggle switches between
/// modes rather than using two separate screens.
class AuthScreen extends StatefulWidget {
  final AppState appState;

  const AuthScreen({super.key, required this.appState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSignup = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
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
        await _auth.signUp(email: _emailCtrl.text, password: _passwordCtrl.text);
      } else {
        await _auth.signIn(email: _emailCtrl.text, password: _passwordCtrl.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: DashboardScreen(appState: widget.appState),
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Enter your email above first, then tap 'Forgot password?'.");
      return;
    }
    try {
      await _auth.sendPasswordReset(_emailCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent."), backgroundColor: _cardColor),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.6),
                radius: 1.3,
                colors: [Color(0xFF10151A), _bgColor],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _brandMark(),
                        const SizedBox(height: 28),
                        _modeToggle(),
                        const SizedBox(height: 24),
                        if (_errorMessage != null) _errorBanner(_errorMessage!),
                        _field(
                          controller: _emailCtrl,
                          label: "Email",
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains("@")) ? "Enter a valid email" : null,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _passwordCtrl,
                          label: "Password",
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          validator: (v) => (v == null || v.length < 6) ? "At least 6 characters" : null,
                        ),
                        if (_isSignup) ...[
                          const SizedBox(height: 14),
                          _field(
                            controller: _confirmCtrl,
                            label: "Confirm password",
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                            validator: (v) => (v != _passwordCtrl.text) ? "Passwords don't match" : null,
                          ),
                        ],
                        if (!_isSignup)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPassword,
                              child: const Text("Forgot password?", style: TextStyle(color: _greenLight)),
                            ),
                          ),
                        const SizedBox(height: 10),
                        _submitButton(),
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

  Widget _brandMark() {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_green, _greenLight]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2)],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleTab("Log in", !_isSignup, () => setState(() => _isSignup = false))),
          Expanded(child: _toggleTab("Sign up", _isSignup, () => setState(() => _isSignup = true))),
        ],
      ),
    );
  }

  Widget _toggleTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _green.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? _greenLight : _textFaint,
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textFaint, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: _textFaint),
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _green, width: 1.4)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      ),
    );
  }

  Widget _submitButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_green, _greenLight]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading ? null : _submit,
          child: Center(
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Text(
                    _isSignup ? "Create account" : "Log in",
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13.5, color: Color(0xFFFCA5A5), height: 1.4)),
    );
  }
}
