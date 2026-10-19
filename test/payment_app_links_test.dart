import 'package:flutter_test/flutter_test.dart';
import 'package:todago/payment_app_links.dart';

void main() {
  test(
      'opens only supported provider app links and preserves the payment token',
      () {
    const gcash = 'gcash://pay/authorize?token=example';
    expect(paymentAppUri(Uri.parse(gcash)).toString(), gcash);
    expect(
        paymentAppUri(Uri.parse('maya://payment?ref=example'))?.scheme, 'maya');
    expect(paymentAppUri(Uri.parse('https://payments.gcash.com')), isNull);
    expect(paymentAppUri(Uri.parse('file:///private/file')), isNull);
    expect(paymentAppUri(Uri.parse('javascript:alert(1)')), isNull);
  });

  test(
      'Android payment intents preserve the provider link but reject other apps',
      () {
    final target = paymentAppUri(Uri.parse(
        'intent://pay/authorize?token=example#Intent;scheme=gcash;package=com.globe.gcash.android;end'));
    expect(target.toString(), 'gcash://pay/authorize?token=example');
    expect(paymentAppUri(Uri.parse('intent://pay#Intent;scheme=unknown;end')),
        isNull);
    expect(paymentAppUri(Uri.parse('intent://pay#Intent;package=unknown;end')),
        isNull);
  });
}
