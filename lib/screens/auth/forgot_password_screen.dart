import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/logo_widget.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
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
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final otp = await authService.forgotPassword(email: _emailCtrl.text.trim());
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
    if (_codeCtrl.text.trim().length != 6 || _newPassCtrl.text.length < 6) {
      _showError('Enter the 6-digit code and a password of at least 6 characters.');
      return;
    }
    setState(() => _loading = true);
    try {
      await authService.resetPassword(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _newPassCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
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
      labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
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
          onPressed: () => Navigator.pop(context),
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
              Text('Reset Password',
                  style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_codeSent ? _resetPassword : _requestCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_codeSent ? 'Reset Password' : 'Send Code',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
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
