import 'package:flutter/material.dart';
import 'identity_verification_screen.dart';

class PersonaVerificationLauncher {
  /// True only after server-confirmed approval and the user taps Back to TodaGo.
  static Future<bool> open(
    BuildContext context,
    String? verificationUrl, {
    String? statusToken,
    String? callbackUrl,
  }) async {
    final url = verificationUrl?.trim();
    if (url == null || url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    return await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => IdentityVerificationScreen(
            verificationUrl: uri,
            statusToken: statusToken,
            callbackUrl: callbackUrl,
          ),
        )) ??
        false;
  }
}
