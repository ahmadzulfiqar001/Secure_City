import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/app_data_store.dart';
import '../../services/sos_service.dart';
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
              style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  void _showSOS() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _SosDialog(store: _store),
    );
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

/// Fetches a real GPS fix as soon as it opens, then on ACTIVATE: logs the
/// SOS to the backend (visible in the admin dashboard) and opens the
/// device's native SMS composer pre-filled to every emergency contact with
/// a Google Maps link — there's no paid SMS gateway configured, so this is
/// the honest way to actually reach contacts rather than pretending to.
class _SosDialog extends StatefulWidget {
  final AppDataStore store;
  const _SosDialog({required this.store});

  @override
  State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  bool _locating = true;
  bool _activating = false;
  double? _lat;
  double? _lng;
  String? _locError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final result = await SosService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _lat = result.lat;
      _lng = result.lng;
      _locError = result.error;
    });
  }

  Future<void> _activate() async {
    setState(() => _activating = true);

    final reported = (_lat != null && _lng != null) ? await SosService.reportToBackend(_lat!, _lng!) : false;

    final phones = widget.store.contacts.map((c) => c.phone).toList();
    final locLine =
        (_lat != null && _lng != null) ? 'My location: https://maps.google.com/?q=$_lat,$_lng' : 'Location unavailable.';
    final message = 'EMERGENCY! I need help.\n$locLine\n— sent via SecureCity';
    final smsOpened = await SosService.sendEmergencySms(phones, message);

    widget.store.triggerSOS(lat: _lat, lng: _lng, reachedBackend: reported, smsOpened: smsOpened);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        phones.isEmpty
            ? 'SOS logged. Add emergency contacts in Profile so SMS can reach someone next time.'
            : smsOpened
                ? 'SOS activated — SMS app opened with your location.'
                : 'SOS logged, but could not open the SMS app on this device.',
        style: GoogleFonts.inter(),
      ),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final contactCount = widget.store.contacts.length;
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.danger.withValues(alpha: 0.12)),
            child: const Icon(Icons.warning_rounded, color: AppColors.danger, size: 42),
          ),
          const SizedBox(height: 18),
          Text('ACTIVATE SOS?',
              style: GoogleFonts.orbitron(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              if (_locating)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(_locError == null ? Icons.check_circle : Icons.error_outline,
                    color: _locError == null ? AppColors.accent : AppColors.accentOrange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locating
                      ? 'Getting your location...'
                      : _locError ?? 'Location ready: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text(
            contactCount == 0
                ? 'No emergency contacts added yet — this will still log an SOS with the monitoring system.'
                : 'This opens your SMS app to message all $contactCount emergency contact${contactCount == 1 ? '' : 's'} with your location, and logs the SOS with the monitoring system.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _activating ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _activating ? null : _activate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _activating
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('ACTIVATE',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
