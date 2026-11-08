import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DemoWalletSnapshot {
  const DemoWalletSnapshot(
      {this.balanceCents = 0, this.transactions = const []});

  final int balanceCents;
  final List<Map<String, dynamic>> transactions;
  double get balance => balanceCents / 100;
  bool get active => transactions.isNotEmpty;
}

/// Local demo data only. This store never calls the payment/wallet backend and
/// its values must never be used to authorize spending, transfers or cash-outs.
class DemoWalletStore {
  static const amounts = [20, 50, 100, 200, 500, 1000];
  static Future<void> _pending = Future<void>.value();

  static String _key(String passengerId) {
    if (passengerId.trim().isEmpty) {
      throw ArgumentError(
          'A passenger account is required for the demo wallet.');
    }
    return 'todago_demo_wallet_v1_${Uri.encodeComponent(passengerId)}';
  }

  static Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  static Future<DemoWalletSnapshot> load(String passengerId) async {
    final key = _key(passengerId);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null) return const DemoWalletSnapshot();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final balance = data['balanceCents'];
      final history = data['transactions'];
      if (balance is! int || balance < 0 || history is! List) {
        return const DemoWalletSnapshot();
      }
      return DemoWalletSnapshot(
        balanceCents: balance,
        transactions: history
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => row['demo'] == true)
            .toList(),
      );
    } catch (_) {
      return const DemoWalletSnapshot();
    }
  }

  static Future<DemoWalletSnapshot> topUp(String passengerId, int amount) =>
      _serialize(() async {
        final key = _key(passengerId);
        if (!amounts.contains(amount)) {
          throw ArgumentError('Choose one of the demo top-up amounts.');
        }
        final previous = await load(passengerId);
        final cents = previous.balanceCents + amount * 100;
        if (cents > 100000000) {
          throw StateError('Reset the demo wallet before adding more funds.');
        }
        final now = DateTime.now();
        final snapshot = DemoWalletSnapshot(balanceCents: cents, transactions: [
          {
            'id': 'demo-${now.microsecondsSinceEpoch}',
            'type': 'topup',
            'status': 'demo',
            'demo': true,
            'title': 'Demo Top-up',
            'subtitle': 'Demo funds · no real payment',
            'amount': amount.toDouble(),
            'occurred_at': now.toIso8601String(),
          },
          ...previous.transactions.take(49),
        ]);
        final preferences = await SharedPreferences.getInstance();
        final saved = await preferences.setString(
            key,
            jsonEncode({
              'balanceCents': snapshot.balanceCents,
              'transactions': snapshot.transactions,
            }));
        if (!saved) throw StateError('The demo top-up could not be saved.');
        return snapshot;
      });

  static Future<void> reset(String passengerId) => _serialize(() async {
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove(_key(passengerId));
      });
}
