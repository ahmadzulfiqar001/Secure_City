/// Form validators. `validatePassword` mirrors the backend's rule exactly
/// (backend/app/core/security.py:25-35) so users hit the same complaint
/// inline instead of on the network round trip.
String? validateRequired(String? value, String label) {
  if (value == null || value.trim().isEmpty) return '$label is required';
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email is required';
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  if (!ok) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'Password must be at least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Password must contain at least one uppercase letter';
  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Password must contain at least one lowercase letter';
  if (!RegExp(r'\d').hasMatch(v)) return 'Password must contain at least one digit';
  return null;
}

String? validateOtpCode(String? value) {
  final v = (value ?? '').trim();
  if (v.length != 6 || !RegExp(r'^\d{6}$').hasMatch(v)) return 'Enter the 6-digit code';
  return null;
}
