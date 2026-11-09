import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'merchant_qr_checkout_session.dart';

class QrGallery {
  static const _channel = MethodChannel('todago/qr_gallery');

  static Future<void> save(String qrId, String expectedSha256) async {
    final session = MerchantQrCheckoutSession(qrCodeId: qrId);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedSha256)) {
      throw const FormatException('Invalid QR image checksum');
    }
    final response =
        await http.get(session.imageUri!).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 2000000 ||
        sha256.convert(response.bodyBytes).toString() != expectedSha256) {
      throw const FormatException(
          'The original QR image could not be verified');
    }
    await _channel.invokeMethod<String>('saveQr', {
      'bytes': response.bodyBytes,
      'fileName': 'TodaGo-$qrId.jpg',
    });
  }
}
