import 'package:url_launcher/url_launcher.dart';

class PersonaVerificationLauncher {
  static Future<bool> open(String? verificationUrl) async {
    final url = verificationUrl?.trim();
    if (url == null || url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}
