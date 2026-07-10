import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/logo_widget.dart';
import '../../widgets/primary_gradient_button.dart';

const _resendCooldownSeconds = 30;

/// Shown right after registration. There's no SMS/email gateway wired up for
/// this prototype, so the code is handed to us directly (`initialOtp`) and
/// shown on screen when no SMTP is configured (see backend/app/core/config.py)
/// — but the verification itself (POST /api/v1/auth/verify-otp) is real.
class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String? initialOtp;

  const OtpScreen({super.key, required this.email, this.initialOtp});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _latestOtp;
  Timer? _cooldownTimer;
  int _cooldownSeconds = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _latestOtp = widget.initialOtp;
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().length != 6) return;
    setState(() => _verifying = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(email: widget.email, code: _codeCtrl.text.trim());
      if (!mounted) return;
      context.go('/home');
    } catch (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$message', style: GoogleFonts.inter()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    setState(() => _resending = true);
    try {
      final otp = await ref.read(authProvider.notifier).resendOtp(email: widget.email);
      if (!mounted) return;
      setState(() => _latestOtp = otp);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('New code generated.', style: GoogleFonts.inter()),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$message', style: GoogleFonts.inter()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Center(child: SecureCityLogo(size: 70, animate: false)),
              const SizedBox(height: 32),
              Text('Verify Your Account',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit code we generated for ${widget.email}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
              if (_latestOtp != null)
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
                        'No SMS/email gateway configured yet — demo code: $_latestOtp',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryLight, height: 1.4),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: AppTheme.monoLarge(color: Colors.white).copyWith(letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: AppTheme.monoLarge(color: AppColors.textMuted).copyWith(letterSpacing: 8),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryGradientButton(label: 'Verify', onPressed: _verify, loading: _verifying),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: (_resending || _cooldownSeconds > 0) ? null : _resend,
                  child: Text(
                    _resending
                        ? 'Sending...'
                        : _cooldownSeconds > 0
                            ? 'Resend in ${_cooldownSeconds}s'
                            : 'Resend Code',
                    style: GoogleFonts.inter(
                      color: _cooldownSeconds > 0 ? AppColors.textMuted : AppColors.primaryLight,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
