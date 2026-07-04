import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/logo_widget.dart';
import '../home/home_screen.dart';

/// Shown right after registration. There's no SMS/email gateway wired up for
/// this prototype, so the code is handed to us directly (`initialOtp`) and
/// shown on screen — see the note in `backend/app/main.py` — but the
/// verification itself (POST /api/auth/verify-otp) is real.
class OtpScreen extends StatefulWidget {
  final String email;
  final String initialOtp;

  const OtpScreen({super.key, required this.email, required this.initialOtp});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  String? _latestOtp;

  @override
  void initState() {
    super.initState();
    _latestOtp = widget.initialOtp;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().length != 6) return;
    setState(() => _verifying = true);
    try {
      await authService.verifyOtp(email: widget.email, code: _codeCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
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
    setState(() => _resending = true);
    try {
      final otp = await authService.resendOtp(email: widget.email);
      if (!mounted) return;
      setState(() => _latestOtp = otp);
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
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                'Enter the 6-digit code we generated for ${widget.email}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
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
                      'No SMS/email gateway configured yet — demo code: ${_latestOtp ?? widget.initialOtp}',
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
                style: GoogleFonts.orbitron(color: Colors.white, fontSize: 22, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.card,
                  hintText: '000000',
                  hintStyle: GoogleFonts.orbitron(color: AppColors.textMuted, fontSize: 22, letterSpacing: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Verify',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? 'Sending...' : 'Resend Code',
                      style: GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
