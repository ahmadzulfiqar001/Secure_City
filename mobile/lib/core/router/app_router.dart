import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/dev/theme_showcase_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/sos/sos_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../services/app_data_store.dart';

/// Routes reachable while logged out (and never redirected away from just
/// because the user isn't authenticated yet).
const _publicRoutes = {'/splash', '/onboarding', '/login', '/register', '/otp', '/forgot-password'};

/// Routes an already-authenticated user shouldn't linger on — landing back
/// on any of these bounces straight to /home.
const _authEntryRoutes = {'/splash', '/onboarding', '/login', '/register'};

/// Bridges Riverpod state changes into something [GoRouter]'s
/// `refreshListenable` understands, so the router re-evaluates `redirect`
/// whenever auth state flips (e.g. a background 401 logs the user out)
/// without recreating the GoRouter instance itself.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      if (location == '/dev/theme') return null;

      if (authState.status == AuthStatus.initial) {
        return location == '/splash' ? null : '/splash';
      }

      final isPublic = _publicRoutes.contains(location);
      if (!authState.isAuthenticated && !isPublic) return '/login';
      if (authState.isAuthenticated && _authEntryRoutes.contains(location)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return OtpScreen(
            email: extra['email'] as String? ?? '',
            initialOtp: extra['otpDebug'] as String?,
          );
        },
      ),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/sos',
        redirect: (context, state) => state.extra is AppDataStore ? null : '/home',
        builder: (context, state) => SosScreen(store: state.extra as AppDataStore),
      ),
      if (kDebugMode)
        GoRoute(path: '/dev/theme', builder: (context, state) => const ThemeShowcaseScreen()),
    ],
  );
});
