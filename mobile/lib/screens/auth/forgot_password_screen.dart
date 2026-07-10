import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/logo_widget.dart';
import '../../widgets/primary_gradient_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _codeSent = false;
  String? _demoOtp;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  void _showError(Object message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$message', style: GoogleFonts.inter()),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _requestCode() async {
    if (validateEmail(_emailCtrl.text) != null) {
      _showError('Enter a valid email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      final otp = await ref.read(authProvider.notifier).forgotPassword(email: _emailCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _demoOtp = otp;
      });
    } catch (message) {
      if (!mounted) return;
      _showError(message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (validateOtpCode(_codeCtrl.text) != null) {
      _showError('Enter the 6-digit code.');
      return;
    }
    final passwordError = validatePassword(_newPassCtrl.text);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).resetPassword(
            email: _emailCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            newPassword: _newPassCtrl.text,
          );
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Password reset — sign in with your new password.', style: GoogleFonts.inter()),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (message) {
      if (!mounted) return;
      _showError(message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(child: SecureCityLogo(size: 70, animate: false)),
              const SizedBox(height: 28),
              Text('Reset Password', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                _codeSent
                    ? 'Enter the code and choose a new password.'
                    : 'Enter your account email and we\'ll generate a reset code.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailCtrl,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                decoration: _decoration('Email Address', Icons.email_outlined),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.primaryLight, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No SMS/email gateway configured yet — demo code: $_demoOtp',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryLight, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, letterSpacing: 4),
                  decoration: _decoration('6-digit code', Icons.pin_outlined).copyWith(counterText: ''),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscure,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  decoration: _decoration(
                    'New Password',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryGradientButton(
                label: _codeSent ? 'Reset Password' : 'Send Code',
                onPressed: _codeSent ? _resetPassword : _requestCode,
                loading: _loading,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _requestCode,
                    child: Text('Resend Code', style: GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 13)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
