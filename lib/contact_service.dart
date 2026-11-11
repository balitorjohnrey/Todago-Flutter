import 'package:url_launcher/url_launcher.dart';

class ContactService {
  static Future<bool> call(String? phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized == null) return false;
    return launchUrl(Uri(scheme: 'tel', path: normalized));
  }

  static String? _normalizePhone(String? phone) {
    final raw = phone?.trim();
    if (raw == null ||
        raw.isEmpty ||
        raw == '-' ||
        raw.toLowerCase() == 'null') {
      return null;
    }
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
