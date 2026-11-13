/// Client-side validators mirroring the backend rules in AccountController::update.
abstract final class Validators {
  static final _name = RegExp(r"^[\p{L}\s\.'-]+$", unicode: true);
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+?[\d\s\-]{7,16}$');

  static String? name(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Please enter your name';
    if (t.length < 2) return 'Name is too short';
    if (t.length > 80) return 'Name is too long';
    if (!_name.hasMatch(t)) return 'Use letters only';
    return null;
  }

  static String? optionalEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return _email.hasMatch(t) ? null : 'Enter a valid email address';
  }

  static String? optionalPhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return _phone.hasMatch(t) ? null : 'Enter a valid phone number';
  }

  static String? requiredPhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    return _phone.hasMatch(t) ? null : 'Enter a valid phone number';
  }

  static String? optionalText(String? v, {int max = 80}) => (v ?? '').trim().length > max ? 'Too long' : null;
}
