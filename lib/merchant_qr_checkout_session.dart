import 'dart:math';

/// Correlates Done with the current in-app QR page. Done only returns to the
/// receipt-reference screen; signed backend confirmation controls every credit.
class MerchantQrCheckoutSession {
  MerchantQrCheckoutSession({this.amount, this.qrCodeId}) {
    if (qrCodeId != null && !RegExp(r'^qr_[a-z0-9]{24}$').hasMatch(qrCodeId!)) {
      throw ArgumentError.value(qrCodeId, 'qrCodeId', 'Invalid passenger QR');
    }
    if (qrCodeId == null &&
        (amount == null ||
            !amount!.isFinite ||
            amount! < 20 ||
            amount! > 50000)) {
      throw ArgumentError.value(amount, 'amount', 'Unsupported top-up amount');
    }
  }

  static final origin =
      Uri.parse('https://todago-qrph.johnmejio11.chatgpt.site');
  final double? amount;
  final String? qrCodeId;
  final String token = List.generate(24, (_) => Random.secure().nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  Uri get pageUri => origin.replace(path: '/', queryParameters: {
        'session': token,
        if (qrCodeId != null) 'qr': qrCodeId!
      });
  Uri? get imageUri =>
      qrCodeId == null ? null : origin.replace(path: '/$qrCodeId.jpg');
  Uri get completionUri =>
      origin.replace(path: '/done.html', queryParameters: {'session': token});

  bool isPage(Uri? uri) => uri == pageUri;
  bool isCompletion(Uri? uri) => uri == completionUri;
}
