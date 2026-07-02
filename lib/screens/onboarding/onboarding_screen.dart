import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _current = 0;

  static const _pages = [
    _OnboardData(
      icon: Icons.videocam_outlined,
      title: 'AI Surveillance',
      desc:
          'Real-time CCTV monitoring powered by YOLOv8. Automatically detects weapons, fights, and suspicious activity — no manual watching needed.',
      iconColor: Color(0xFF7C3AED),
    ),
    _OnboardData(
      icon: Icons.groups_outlined,
      title: 'Crowd Detection',
      desc:
          'Smart crowd behavior analysis identifies overcrowding, panic movements, and abnormal gatherings before they escalate into emergencies.',
      iconColor: Color(0xFF06D6A0),
    ),
    _OnboardData(
      icon: Icons.sos_rounded,
      title: 'Emergency SOS',
      desc:
          'One tap activates your panic button — instantly shares live location with emergency contacts and notifies authorities in real time.',
      iconColor: Color(0xFFEF4444),
    ),
  ];

  void _next() {
    if (_current < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _PageView(data: _pages[i]),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 52),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _ctrl,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      expansionFactor: 3,
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.border,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      if (_current > 0)
                        TextButton(
                          onPressed: () => _ctrl.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          child: Text('Back',
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted, fontSize: 15)),
                        ),
                      const Spacer(),
                      if (_current < _pages.length - 1)
                        TextButton(
                          onPressed: _goToLogin,
                          child: Text('Skip',
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted, fontSize: 15)),
                        ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50)),
                        ),
                        child: Text(
                          _current < _pages.length - 1
                              ? 'Next'
                              : 'Get Started',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title;
  final String desc;
  final Color iconColor;

  const _OnboardData(
      {required this.icon,
      required this.title,
      required this.desc,
      required this.iconColor});
}

class _PageView extends StatelessWidget {
  final _OnboardData data;

  const _PageView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // Icon circle
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.iconColor.withOpacity(0.18),
                  data.iconColor.withOpacity(0.04),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                  color: data.iconColor.withOpacity(0.25), width: 1.2),
            ),
            child: Icon(data.icon, size: 70, color: data.iconColor),
          ),

          const SizedBox(height: 52),

          Text(
            data.title,
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            data.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),

          const SizedBox(height: 180),
        ],
      ),
    );
  }
}
