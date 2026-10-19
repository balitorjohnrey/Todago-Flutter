import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'payment_method_logo.dart';
import 'wallet_checkout_screen.dart';
import 'wallet_service.dart';

/// TodaGo's Payment API checkout. Provider authorization pages stay in a WebView.
class WalletPaymentScreen extends StatefulWidget {
  const WalletPaymentScreen(
      {super.key,
      required this.transactionId,
      this.payment,
      this.checkPayment = WalletService.checkTopUp});
  final String transactionId;
  final Map<String, dynamic>? payment;
  final Future<Map<String, dynamic>> Function(String) checkPayment;

  @override
  State<WalletPaymentScreen> createState() => _WalletPaymentScreenState();
}

class _WalletPaymentScreenState extends State<WalletPaymentScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _payment;
  Timer? _timer;
  bool _checking = false;
  bool _opening = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _payment = widget.payment;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _verify());
    if (_payment == null) _verify();
  }

  Future<void> _verify() async {
    if (_checking || _finished || !mounted) return;
    _checking = true;
    try {
      final result = await widget.checkPayment(widget.transactionId);
      if (!mounted || _finished) return;
      if (result['success'] == true) {
        final status = result['status'];
        if (status == 'completed' ||
            status == 'cancelled' ||
            status == 'failed') {
          // If an authorization WebView is above us, it also polls and closes
          // itself. Never pop an unrelated route while our page is covered.
          if (ModalRoute.of(context)?.isCurrent == true) {
            _finish(status as String);
          }
          return;
        }
        setState(() {
          if (result['payment'] is Map) {
            _payment = Map<String, dynamic>.from(result['payment'] as Map);
          }
          _error = null;
        });
      } else {
        setState(() => _error = result['message']?.toString() ??
            'Unable to check payment. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to check payment. Try again.');
      }
    } finally {
      _checking = false;
    }
  }

  void _finish(String status) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(status);
  }

  Future<void> _authorize({bool simulator = false}) async {
    if (_opening) return;
    final raw =
        _payment?[simulator ? 'testUrl' : 'authorizationUrl']?.toString();
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri?.scheme != 'https' ||
        uri!.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (simulator &&
            !(uri.host == 'paymongo.com' ||
                uri.host.endsWith('.paymongo.com')))) {
      setState(() => _error = simulator
          ? 'The test simulator is not available for this payment yet. Refresh or create a new test top-up.'
          : 'The authorization page is unavailable. Refresh or create a new top-up.');
      return;
    }
    setState(() => _opening = true);
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => WalletCheckoutScreen(
          checkoutUrl: uri.toString(),
          transactionId: widget.transactionId,
          testMode: _testMode,
          providerAuthorization: true,
          providerLabel: simulator ? 'test simulator' : _label),
    ));
    if (!mounted) return;
    setState(() => _opening = false);
    if (result == 'completed' || result == 'cancelled' || result == 'failed') {
      _finish(result!);
    } else {
      await _verify();
    }
  }

  String get _provider => _payment?['provider']?.toString() ?? '';
  String get _label => switch (_provider) {
        'gcash' => 'GCash',
        'maya' => 'Maya',
        'qrph' => 'QR Ph',
        _ => 'payment provider'
      };
  bool get _testMode => _payment?['testMode'] == true;
  bool get _hasAction => _payment?['status'] == 'awaiting_next_action';

  Widget _qrImage(String source) {
    if (source.startsWith('data:image/png;base64,') ||
        source.startsWith('data:image/jpeg;base64,')) {
      try {
        return Image.memory(
            base64Decode(source.substring(source.indexOf(',') + 1)),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('QR image could not load. Refresh to try again.'));
      } on FormatException {
        return const Text('QR image could not load. Refresh to try again.');
      }
    }
    if (Uri.tryParse(source)?.scheme == 'https') {
      return Image.network(source,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Text('QR image could not load. Refresh to try again.'));
    }
    return const Text('QR image is unavailable. Refresh to try again.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Top up wallet'),
            leading: IconButton(
                tooltip: 'Back to wallet',
                icon: const Icon(Icons.close),
                onPressed: () => _finish('pending')),
            actions: [
              IconButton(
                  tooltip: 'Check payment',
                  icon: const Icon(Icons.refresh),
                  onPressed: _verify)
            ]),
        body: _payment == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/logo.png', height: 64),
                      const SizedBox(height: 16),
                      const Text('TodaGo wallet top-up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (_payment != null)
                        Text(
                            '₱${(num.tryParse('${_payment!['amount']}') ?? 0).toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 24),
                      if (_payment != null && !_testMode) ...[
                        const Text('LIVE PAYMENT • Uses real money',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                      ],
                      if (_testMode) ...[
                        const Icon(Icons.science_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text('TEST PAYMENT',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text(
                            'Use the simulator to test payment. Do not send real money or pay a QR code.',
                            textAlign: TextAlign.center),
                        if (_provider == 'qrph') ...[
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed:
                                  _opening || _payment?['testUrl'] == null
                                      ? null
                                      : () => _authorize(simulator: true),
                              child: const Text('Open test simulator')),
                          if (_payment?['testUrl'] == null)
                            const Text(
                                'Simulator link unavailable. Refresh to check again.',
                                textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 20),
                      ],
                      if (_provider == 'qrph' && !_testMode) ...[
                        const Text('Pay using QR Ph',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                            'Use a participating bank or e-wallet to pay this QR code.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        if (_hasAction && _payment?['qrImageUrl'] is String)
                          Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              child: AspectRatio(
                                  aspectRatio: 1,
                                  child: _qrImage(
                                      _payment!['qrImageUrl'] as String)))
                        else
                          const Text(
                              'This QR code is no longer available. Return to your wallet and start a new top-up.',
                              textAlign: TextAlign.center),
                      ],
                      if (_provider == 'gcash' || _provider == 'maya') ...[
                        Center(
                            child: PaymentMethodLogo(
                                provider: _provider, width: 120)),
                        const SizedBox(height: 16),
                        Text('Securely authorize your payment with $_label.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _opening || !_hasAction
                                ? null
                                : () => _authorize(),
                            child: Text(_testMode
                                ? 'Continue to $_label test payment'
                                : 'Continue to $_label')),
                        const SizedBox(height: 8),
                        Text(
                            _provider == 'gcash'
                                ? 'The secure page opens here. Tap “Open in GCash” to authorize in the GCash app, then return to TodaGo.'
                                : 'The secure Maya page opens here. Complete the authorization steps provided by Maya, then return to TodaGo.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ],
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: AppColors.error))),
                      const SizedBox(height: 24),
                      const Text(
                          'Waiting for payment confirmation. Your wallet updates after payment is confirmed.',
                          textAlign: TextAlign.center),
                    ])),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                    onPressed: () => _finish('pending'),
                    child: const Text('Back to wallet')))),
      );
}
