import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/app_data_store.dart';
import '../alerts/alerts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';

/// Shell that owns the shared [AppDataStore] and hosts the four module
/// pages (Dashboard, Alerts, Map, Profile) behind the bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = AppDataStore();
  int _tab = 0;

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _body()),
      bottomNavigationBar: _bottomNav(),
      floatingActionButton: _sosBtn(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return DashboardScreen(
          store: _store,
          onSeeAllAlerts: () => setState(() => _tab = 1),
          onOpenMap: () => setState(() => _tab = 2),
          onOpenProfile: () => setState(() => _tab = 3),
        );
      case 1:
        return AlertsScreen(store: _store);
      case 2:
        return MapScreen(store: _store, fullScreen: true);
      case 3:
        return ProfileScreen(store: _store);
      default:
        return DashboardScreen(
          store: _store,
          onSeeAllAlerts: () => setState(() => _tab = 1),
          onOpenMap: () => setState(() => _tab = 2),
          onOpenProfile: () => setState(() => _tab = 3),
        );
    }
  }

  Widget _sosBtn() {
    return GestureDetector(
      onTap: _showSOS,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.55), blurRadius: 18, spreadRadius: 2)],
        ),
        child: Center(
          child: Text('SOS',
              style: GoogleFonts.sora(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  void _showSOS() {
    context.push('/sos', extra: _store);
  }

  Widget _bottomNav() {
    return BottomAppBar(
      color: AppColors.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(children: [
        _navItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
        _navItem(1, Icons.notifications_outlined, Icons.notifications_rounded, 'Alerts'),
        const Expanded(child: SizedBox()),
        _navItem(2, Icons.map_outlined, Icons.map_rounded, 'Map'),
        _navItem(3, Icons.person_outline, Icons.person_rounded, 'Profile'),
      ]),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, color: active ? AppColors.primary : AppColors.textMuted, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: active ? AppColors.primary : AppColors.textMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
