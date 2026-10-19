/// Only payment-provider schemes may leave the checkout WebView.
Uri? paymentAppUri(Uri uri) {
  const schemes = {
    'gcash',
    'paymaya',
    'maya',
    'grab',
    'grabpay',
    'shopee',
    'shopeepay'
  };
  var target = uri;
  if (uri.scheme == 'intent') {
    final scheme = RegExp(r'(?:^|;)scheme=([a-zA-Z0-9+.-]+)(?:;|$)')
        .firstMatch(uri.fragment)
        ?.group(1);
    if (scheme == null) return null;
    target = uri.replace(scheme: scheme).removeFragment();
  }
  return schemes.contains(target.scheme.toLowerCase()) ? target : null;
}
