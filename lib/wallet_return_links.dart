import 'package:app_links/app_links.dart';

class WalletReturnLinks {
  static final _links = AppLinks();
  static Uri? _initialLink;

  static bool isWalletReturn(Uri uri) =>
      uri.scheme == 'todago' && uri.host == 'wallet';

  static Future<void> initialize() async {
    _initialLink = await _links.getInitialLink();
  }

  static bool takeInitialWalletReturn() {
    final isReturn = _initialLink != null && isWalletReturn(_initialLink!);
    _initialLink = null;
    return isReturn;
  }

  static Stream<Uri> get stream => _links.uriLinkStream.where(isWalletReturn);
}
