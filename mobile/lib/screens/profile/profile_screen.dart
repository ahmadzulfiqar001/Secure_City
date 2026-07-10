import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/emergency_contact_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_data_store.dart';

class ProfileScreen extends ConsumerWidget {
  final AppDataStore store;
  const ProfileScreen({super.key, required this.store});

  void _addContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
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
                    validator: (v) => validateRequired(v, 'Name')),
                const SizedBox(height: 12),
                _dialogField(relationCtrl, 'Relation (e.g. Sister)', Icons.family_restroom_outlined,
                    validator: (v) => validateRequired(v, 'Relation')),
                const SizedBox(height: 12),
                _dialogField(phoneCtrl, 'Phone Number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => validateRequired(v, 'Phone')),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
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
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() => saving = true);
                              try {
                                await store.addContact(
                                  name: nameCtrl.text.trim(),
                                  relation: relationCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setDialogState(() => saving = false);
                                if (ctx.mounted) _showError(ctx, e);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Add', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Logout?',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('You will need to sign in again to access your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
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
                  onPressed: () async {
                    // The router's redirect reacts to authProvider flipping
                    // to unauthenticated, so no manual navigation here.
                    await ref.read(authProvider.notifier).logout();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Logout', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showError(BuildContext context, Object message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$message', style: GoogleFonts.inter()),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter()),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _verifyNow(BuildContext context, WidgetRef ref) async {
    final email = ref.read(authProvider).user?.email;
    if (email == null) return;
    try {
      final otp = await ref.read(authProvider.notifier).resendOtp(email: email);
      if (!context.mounted) return;
      context.push('/otp', extra: {'email': email, 'otpDebug': otp});
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  void _editProfileDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Edit Profile',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                _dialogField(nameCtrl, 'Full Name', Icons.person_outline,
                    validator: (v) => validateRequired(v, 'Name')),
                const SizedBox(height: 12),
                _dialogField(phoneCtrl, 'Phone Number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => validateRequired(v, 'Phone')),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
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
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() => saving = true);
                              try {
                                await ref
                                    .read(authProvider.notifier)
                                    .updateProfile(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim());
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (context.mounted) _showSuccess(context, 'Profile updated.');
                              } catch (e) {
                                setDialogState(() => saving = false);
                                if (ctx.mounted) _showError(ctx, e);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  void _changePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Change Password',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                _dialogField(currentCtrl, 'Current Password', Icons.lock_outline,
                    obscure: true, validator: (v) => validateRequired(v, 'Current password')),
                const SizedBox(height: 12),
                _dialogField(newCtrl, 'New Password', Icons.lock_reset_outlined,
                    obscure: true, validator: validatePassword),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : () => Navigator.pop(ctx),
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
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() => saving = true);
                              try {
                                // Succeeding here revokes every session
                                // server-side, so the notifier logs out
                                // locally too — the router redirect handles
                                // bouncing to /login.
                                await ref
                                    .read(authProvider.notifier)
                                    .changePassword(current: currentCtrl.text, newPassword: newCtrl.text);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (context.mounted) {
                                  _showSuccess(context, 'Password changed — please sign in again.');
                                }
                              } catch (e) {
                                setDialogState(() => saving = false);
                                if (ctx.mounted) _showError(ctx, e);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Change', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  void _deleteAccountDialog(BuildContext context, WidgetRef ref) {
    bool deleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_rounded, color: AppColors.danger, size: 36),
              const SizedBox(height: 12),
              Text('Delete Account?',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('This permanently deletes your account. This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: deleting ? null : () => Navigator.pop(ctx),
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
                    onPressed: deleting
                        ? null
                        : () async {
                            setDialogState(() => deleting = true);
                            try {
                              await ref.read(authProvider.notifier).deleteAccount();
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setDialogState(() => deleting = false);
                              if (ctx.mounted) _showError(ctx, e);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: deleting
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, bool obscure = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscure,
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final user = ref.watch(authProvider).user;
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
                Text(user?.name ?? 'SecureCity User',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(user?.email ?? '',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                if (user?.isVerified == false) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.accentOrange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Account not verified',
                            style: GoogleFonts.inter(color: AppColors.accentOrange, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => _verifyNow(context, ref),
                        child: Text('Verify Now',
                            style: GoogleFonts.inter(
                                color: AppColors.accentOrange, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
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
                const SizedBox(height: 24),
                _sectionHeader('Account'),
                const SizedBox(height: 12),
                _actionTile('Edit Profile', Icons.edit_outlined, AppColors.accent,
                    () => _editProfileDialog(context, ref)),
                _actionTile('Change Password', Icons.lock_reset_outlined, AppColors.accent,
                    () => _changePasswordDialog(context, ref)),
                _actionTile('Delete Account', Icons.delete_forever_outlined, AppColors.danger,
                    () => _deleteAccountDialog(context, ref)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
                    label: Text('Logout',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _pStat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(l, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 36, color: AppColors.border);

  Widget _sectionHeader(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ]),
          ),
        ),
      ),
    );
  }

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
