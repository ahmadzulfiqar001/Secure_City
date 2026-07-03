import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/emergency_contact_model.dart';
import '../../services/app_data_store.dart';

class ProfileScreen extends StatelessWidget {
  final AppDataStore store;
  const ProfileScreen({super.key, required this.store});

  void _addContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Add Emergency Contact',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              _dialogField(nameCtrl, 'Full Name', Icons.person_outline,
                  validator: (v) => v!.isEmpty ? 'Name is required' : null),
              const SizedBox(height: 12),
              _dialogField(relationCtrl, 'Relation (e.g. Sister)', Icons.family_restroom_outlined,
                  validator: (v) => v!.isEmpty ? 'Relation is required' : null),
              const SizedBox(height: 12),
              _dialogField(phoneCtrl, 'Phone Number', Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Phone is required' : null),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      store.addContact(EmergencyContact(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        relation: relationCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        icon: Icons.person_outline,
                        color: AppColors.accent,
                      ));
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            const trips = 47;
            const safeArrivals = 45;
            final safetyScore = ((safeArrivals / trips) * 100).round();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              child: Column(children: [
                const SizedBox(height: 10),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 12),
                Text('Muhammad Ahmad',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('FA23-BCS-051  •  SecureCity User',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                      color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    _pStat('$trips', 'Trips'),
                    _divider(),
                    _pStat('$safeArrivals', 'Safe Arrivals'),
                    _divider(),
                    _pStat('$safetyScore%', 'Safety Score'),
                  ]),
                ),
                const SizedBox(height: 24),
                _sectionHeader('Emergency Contacts'),
                const SizedBox(height: 12),
                ...store.contacts.map((c) => Dismissible(
                      key: ValueKey(c.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => store.removeContact(c.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.delete_outline, color: AppColors.danger),
                      ),
                      child: _contactTile(c),
                    )),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addContactDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Add Emergency Contact', style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionHeader('Safety Preferences'),
                const SizedBox(height: 12),
                ...store.preferences.entries.map((e) => _prefTile(e.key, e.value)),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _pStat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(l, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 36, color: AppColors.border);

  Widget _sectionHeader(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  Widget _contactTile(EmergencyContact c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(c.icon, color: c.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(c.relation, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
          ],
        )),
        const Icon(Icons.phone_outlined, color: AppColors.accent, size: 18),
      ]),
    );
  }

  Widget _prefTile(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
        Switch(
          value: value,
          onChanged: (v) => store.setPreference(label, v),
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.primary,
          inactiveThumbColor: AppColors.textMuted,
          inactiveTrackColor: AppColors.border,
        ),
      ]),
    );
  }
}
