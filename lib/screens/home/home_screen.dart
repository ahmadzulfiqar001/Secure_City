import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong2.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/logo_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  final _mapCtrl = MapController();

  // Islamabad / Rawalpindi coordinates
  static const _center = LatLng(33.7215, 73.0433);

  final _cameras = [
    _CamPin(LatLng(33.7294, 73.0931), 'CAM-01', 'Saddar Market'),
    _CamPin(LatLng(33.7296, 73.0880), 'CAM-02', 'Raja Bazaar'),
    _CamPin(LatLng(33.7215, 73.0433), 'CAM-03', 'Blue Area'),
    _CamPin(LatLng(33.7080, 73.0479), 'CAM-04', 'F-10 Markaz'),
    _CamPin(LatLng(33.6938, 73.0651), 'CAM-05', 'Centaurus Mall'),
    _CamPin(LatLng(33.6844, 73.0479), 'CAM-06', 'Liaquat Bagh'),
  ];

  final _alerts = [
    _Alert('Fight Detected', 'Saddar Market, Rawalpindi',
        LatLng(33.7294, 73.0931), '2 min ago', _Sev.high,
        Icons.sports_kabaddi_outlined),
    _Alert('Crowd Anomaly', 'Blue Area, Islamabad',
        LatLng(33.7215, 73.0433), '15 min ago', _Sev.medium,
        Icons.groups_outlined),
    _Alert('Weapon Detected', 'Raja Bazaar, Rawalpindi',
        LatLng(33.7296, 73.0880), '42 min ago', _Sev.high,
        Icons.warning_amber_rounded),
    _Alert('Suspicious Activity', 'F-10 Markaz, Islamabad',
        LatLng(33.7080, 73.0479), '1 hr ago', _Sev.low,
        Icons.visibility_outlined),
    _Alert('Panic Movement', 'Centaurus Mall',
        LatLng(33.6938, 73.0651), '2 hr ago', _Sev.medium,
        Icons.directions_run),
    _Alert('Overcrowding', 'Liaquat Bagh',
        LatLng(33.6844, 73.0479), '3 hr ago', _Sev.low,
        Icons.people_outlined),
  ];

  Color _sevColor(_Sev s) => {
        _Sev.high: AppColors.danger,
        _Sev.medium: AppColors.accentOrange,
        _Sev.low: AppColors.accent,
      }[s]!;

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Camera markers (purple)
    for (final cam in _cameras) {
      markers.add(Marker(
        point: cam.point,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showCamInfo(cam),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ],
            ),
            child: const Icon(Icons.videocam, color: Colors.white, size: 18),
          ),
        ),
      ));
    }

    // Alert markers
    for (final alert in _alerts) {
      final color = _sevColor(alert.severity);
      markers.add(Marker(
        point: alert.loc,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showAlertInfo(alert),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Icon(alert.icon, color: Colors.white, size: 16),
          ),
        ),
      ));
    }

    return markers;
  }

  void _showCamInfo(_CamPin cam) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InfoSheet(
        icon: Icons.videocam_rounded,
        iconColor: AppColors.primary,
        title: cam.id,
        subtitle: cam.label,
        status: 'Active — Live Feed',
        statusColor: AppColors.accent,
      ),
    );
  }

  void _showAlertInfo(_Alert alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InfoSheet(
        icon: alert.icon,
        iconColor: _sevColor(alert.severity),
        title: alert.type,
        subtitle: alert.location,
        status: alert.time,
        statusColor: _sevColor(alert.severity),
        badge: alert.severity.name.toUpperCase(),
      ),
    );
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
        return _dashboard();
      case 1:
        return _alertsTab();
      case 2:
        return _mapFullTab();
      case 3:
        return _profileTab();
      default:
        return _dashboard();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DASHBOARD
  // ═══════════════════════════════════════════════════════════════
  Widget _dashboard() {
    return CustomScrollView(
      slivers: [
        // App bar
        SliverToBoxAdapter(child: _header()),

        // Stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _statsRow(),
          ),
        ),

        // Map section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Live Safety Map'),
                const SizedBox(height: 10),
                _mapWidget(height: 260),
              ],
            ),
          ),
        ),

        // Alerts section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: _sectionHeader(
              'Recent Alerts',
              onTap: () => setState(() => _tab = 1),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _alertTile(_alerts[i]),
              childCount: _alerts.length > 3 ? 3 : _alerts.length,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          const SecureCityLogo(size: 40, animate: true),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SecureCity',
                  style: GoogleFonts.orbitron(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5)),
              Row(children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Monitoring Active',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.accent)),
              ]),
            ],
          ),
          const Spacer(),
          Stack(children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 24),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.danger, shape: BoxShape.circle)),
            ),
          ]),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STATS ROW
  // ═══════════════════════════════════════════════════════════════
  Widget _statsRow() {
    return Row(children: [
      Expanded(
          child: _statCard('12', 'Cameras', Icons.videocam_outlined,
              AppColors.accent)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard(
              '${_alerts.where((a) => a.severity == _Sev.high).length}',
              'Critical',
              Icons.warning_rounded,
              AppColors.danger)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('MED', 'Risk Level', Icons.shield_outlined,
              AppColors.primary)),
    ]);
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(val,
            style: GoogleFonts.orbitron(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textMuted)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MAP WIDGET (real flutter_map)
  // ═══════════════════════════════════════════════════════════════
  Widget _mapWidget({double height = 300, bool fullScreen = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(fullScreen ? 0 : 16),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: const MapOptions(
              initialCenter: _center,
              initialZoom: 12.5,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Dark map tiles from CartoDB (no API key needed)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.securecity.app',
              ),
              // Markers
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Safety legend top-right
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendRow(AppColors.primary, Icons.videocam, 'Camera'),
                  const SizedBox(height: 5),
                  _legendRow(AppColors.danger, Icons.warning_rounded, 'High'),
                  const SizedBox(height: 5),
                  _legendRow(AppColors.accentOrange, Icons.warning_amber_rounded,
                      'Medium'),
                  const SizedBox(height: 5),
                  _legendRow(AppColors.accent, Icons.info_outline, 'Low'),
                ],
              ),
            ),
          ),

          // Recenter button bottom-right
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                _mapCtrl.move(_center, 12.5);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _legendRow(Color color, IconData icon, String label) {
    return Row(children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 5),
      Text(label,
          style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 10)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  //  FULL MAP TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _mapFullTab() {
    return Stack(children: [
      _mapWidget(
          height: MediaQuery.of(context).size.height, fullScreen: true),

      // Bottom info bar
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.background,
                AppColors.background.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(children: [
            _quickInfo(Icons.videocam, '${_cameras.length}', 'Cams',
                AppColors.primary),
            const SizedBox(width: 10),
            _quickInfo(Icons.warning_rounded,
                '${_alerts.where((a) => a.severity == _Sev.high).length}',
                'Critical', AppColors.danger),
            const SizedBox(width: 10),
            _quickInfo(Icons.warning_amber_rounded,
                '${_alerts.where((a) => a.severity == _Sev.medium).length}',
                'Medium', AppColors.accentOrange),
            const SizedBox(width: 10),
            _quickInfo(Icons.check_circle_outline,
                '${_alerts.where((a) => a.severity == _Sev.low).length}',
                'Low', AppColors.accent),
          ]),
        ),
      ),
    ]);
  }

  Widget _quickInfo(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(val,
              style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 9)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ALERTS TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _alertsTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(children: [
          Text('Alerts',
              style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_alerts.where((a) => a.severity == _Sev.high).length} Critical',
              style: GoogleFonts.inter(
                  color: AppColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Filter chips
      SizedBox(
        height: 36,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          children: [
            _filterChip('All', true),
            const SizedBox(width: 8),
            _filterChip('High', false, color: AppColors.danger),
            const SizedBox(width: 8),
            _filterChip('Medium', false, color: AppColors.accentOrange),
            const SizedBox(width: 8),
            _filterChip('Low', false, color: AppColors.accent),
          ],
        ),
      ),

      const SizedBox(height: 12),

      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          itemCount: _alerts.length,
          itemBuilder: (_, i) => _alertTile(_alerts[i]),
        ),
      ),
    ]);
  }

  Widget _filterChip(String label, bool active, {Color? color}) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: active ? c : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? c : AppColors.border),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: active ? Colors.white : AppColors.textMuted,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
    );
  }

  Widget _alertTile(_Alert alert) {
    final color = _sevColor(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showAlertInfo(alert),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(alert.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.type,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 3),
                    Text(alert.location,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(alert.time,
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    alert.severity.name.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROFILE TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _profileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(children: [
        const SizedBox(height: 10),

        // Avatar + name
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark]),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2)
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 12),
        Text('Muhammad Ahmad',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('FA23-BCS-051  •  SecureCity User',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 12)),

        const SizedBox(height: 28),

        // Stats
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            _pStat('47', 'Trips'),
            _divider(),
            _pStat('45', 'Safe Arrivals'),
            _divider(),
            _pStat('82%', 'Safety Score'),
          ]),
        ),

        const SizedBox(height: 24),

        _sectionHeader('Emergency Contacts'),
        const SizedBox(height: 12),
        _contactTile('Fatima Khan', 'Mother', Icons.favorite_outline,
            AppColors.danger),
        _contactTile('Ahmed Khan', 'Brother', Icons.person_outline,
            AppColors.accent),
        _contactTile('Rescue 1122', 'Emergency Service',
            Icons.local_police_outlined, AppColors.accentOrange),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add Emergency Contact',
                style: GoogleFonts.inter(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 24),

        _sectionHeader('Safety Preferences'),
        const SizedBox(height: 12),
        _prefTile('Avoid Isolated Areas', true),
        _prefTile('Prefer Crowded Routes', true),
        _prefTile('Night Mode Alerts', false),
      ]),
    );
  }

  Widget _pStat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v,
              style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(l,
              style:
                  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ]),
      );

  Widget _divider() =>
      Container(width: 1, height: 36, color: AppColors.border);

  Widget _contactTile(
      String name, String role, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text(role,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 11)),
          ],
        )),
        Icon(Icons.phone_outlined, color: AppColors.accent, size: 18),
      ]),
    );
  }

  Widget _prefTile(String label, bool init) {
    return StatefulBuilder(builder: (_, set) {
      bool val = init;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 13))),
          Switch(
            value: val,
            onChanged: (v) => set(() => val = v),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.border,
          ),
        ]),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  SOS BUTTON
  // ═══════════════════════════════════════════════════════════════
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
          boxShadow: [
            BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 2)
          ],
        ),
        child: Center(
          child: Text('SOS',
              style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ),
      ),
    );
  }

  void _showSOS() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withValues(alpha: 0.12)),
              child: const Icon(Icons.warning_rounded,
                  color: AppColors.danger, size: 42),
            ),
            const SizedBox(height: 18),
            Text('ACTIVATE SOS?',
                style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            Text(
              'Your live location will be shared with all emergency contacts immediately.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.6),
            ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('SOS Activated! Location shared.',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('ACTIVATE',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ═══════════════════════════════════════════════════════════════
  Widget _bottomNav() {
    return BottomAppBar(
      color: AppColors.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(children: [
        _navItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
        _navItem(1, Icons.notifications_outlined,
            Icons.notifications_rounded, 'Alerts'),
        const Expanded(child: SizedBox()),
        _navItem(2, Icons.map_outlined, Icons.map_rounded, 'Map'),
        _navItem(3, Icons.person_outline, Icons.person_rounded, 'Profile'),
      ]),
    );
  }

  Widget _navItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final active = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? AppColors.primary : AppColors.textMuted,
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color:
                        active ? AppColors.primary : AppColors.textMuted,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════
  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5));

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Text('See All',
                  style: GoogleFonts.inter(
                      color: AppColors.primaryLight, fontSize: 13)),
            ),
        ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  BOTTOM SHEET INFO
// ═══════════════════════════════════════════════════════════════════
class _InfoSheet extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle, status;
  final Color statusColor;
  final String? badge;

  const _InfoSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
        ),
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          )),
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Text(badge!,
                  style: GoogleFonts.inter(
                      color: iconColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.access_time, color: statusColor, size: 14),
          const SizedBox(width: 6),
          Text(status,
              style: GoogleFonts.inter(color: statusColor, fontSize: 13)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text('Close',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════════
enum _Sev { high, medium, low }

class _Alert {
  final String type, location, time;
  final LatLng loc;
  final _Sev severity;
  final IconData icon;

  const _Alert(this.type, this.location, this.loc, this.time, this.severity,
      this.icon);
}

class _CamPin {
  final LatLng point;
  final String id, label;
  const _CamPin(this.point, this.id, this.label);
}
