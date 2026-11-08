import 'package:shared_preferences/shared_preferences.dart';

class WalletMigration {
  /// Removes only the retired local preview wallets. Confirmed balances and
  /// transaction history always come from the backend; auth and rides stay put.
  static Future<void> clearLocalPreviewBalances() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith('todago_demo_wallet_v1_'))
        .toList();
    for (final key in keys) {
      await preferences.remove(key);
    }
  }
}
