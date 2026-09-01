import "package:flutter/material.dart";

import "../services/auth_service.dart";
import "../theme/app_theme.dart";
import "signup_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  final bool _captchaVerified = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_captchaVerified) {
      setState(() => _errorMessage = "Complete verification to proceed.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _auth.signIn(email: _emailCtrl.text, password: _passwordCtrl.text);
      // AuthGate's stream listener handles navigation on success.
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
        const SnackBar(content: Text("Password reset email sent.")),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Text(
                      'Hello!',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Securely log in with your email and password.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 28),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF151515),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_errorMessage != null) _errorBanner(_errorMessage!),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: Color(0xFFF4F6F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide(color: AppColors.primary, width: 1.2),
                                  ),
                                  hintText: 'Enter your mail',
                                  hintStyle: TextStyle(color: Color(0xFF7A7A7A)),
                                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: Color(0xFF6D6D6D)),
                                ),
                                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: Color(0xFFF4F6F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(14)),
                                    borderSide: BorderSide(color: AppColors.primary, width: 1.2),
                                  ),
                                  hintText: 'Enter your Password',
                                  hintStyle: TextStyle(color: Color(0xFF7A7A7A)),
                                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF6D6D6D)),
                                ),
                                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Checkbox(
                                    value: false,
                                    onChanged: (_) {},
                                    activeColor: AppColors.primary,
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Remember me',
                                      style: TextStyle(color: Color(0xFF3A3A3A)),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _forgotPassword,
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                    : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(color: Color(0xFF3C3C3C)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                                    child: const Text(
                                      'Sign up',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.error, height: 1.4)),
    );
  }
}
