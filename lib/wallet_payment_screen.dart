import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'payment_method_logo.dart';
import 'wallet_checkout_screen.dart';
import 'wallet_service.dart';
import 'qr_ph_wallets.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _checking = false;
  bool _opening = false;
  bool _showLiveQr = false;
  bool _finished = false;
  String? _error;

  void _changeQrView(bool visible) {
    setState(() => _showLiveQr = visible);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

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
            if (_testMode || _provider != 'qrph') _showLiveQr = false;
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

  Uri? get _testAuthorizationUri {
    final raw = _payment?['testUrl']?.toString();
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri?.scheme != 'https' ||
        uri!.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !(uri.host == 'paymongo.com' || uri.host.endsWith('.paymongo.com'))) {
      return null;
    }
    return uri;
  }

  Future<void> _authorize({bool testPayment = false}) async {
    if (_opening) return;
    final raw = _payment?['authorizationUrl']?.toString();
    final uri = testPayment
        ? _testAuthorizationUri
        : raw == null
            ? null
            : Uri.tryParse(raw);
    if (uri?.scheme != 'https' ||
        uri!.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      setState(() => _error = testPayment
          ? 'Test authorization is unavailable. Refresh or start a new test top-up.'
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
          providerLabel: _label),
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
  // Only an explicitly live response may expose a payable QR code.
  bool get _testMode => _payment?['testMode'] != false;
  bool get _hasAction => _payment?['status'] == 'awaiting_next_action';
  bool get _staticQr => _payment?['kind'] == 'static_qr';
  String get _formattedAmount =>
      '₱${(num.tryParse('${_payment?['amount']}') ?? 0).toStringAsFixed(2)}';
  bool get _liveQrAvailable {
    if (_testMode || !_hasAction || _provider != 'qrph') return false;
    final source = _payment?['qrImageUrl'];
    return source is String &&
        (source.startsWith('data:image/png;base64,') ||
            source.startsWith('data:image/jpeg;base64,') ||
            Uri.tryParse(source)?.scheme == 'https');
  }

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
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_showLiveQr ? 'Scan QR Ph' : 'Top up wallet'),
                  if (_payment != null)
                    Text(_testMode ? 'Sandbox' : 'Live payment',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primary)),
                ]),
            leading: IconButton(
                tooltip: _showLiveQr ? 'Back to top-up' : 'Back to wallet',
                icon: Icon(_showLiveQr ? Icons.arrow_back : Icons.close),
                onPressed: _showLiveQr
                    ? () => _changeQrView(false)
                    : () => _finish('pending')),
            actions: [
              IconButton(
                  tooltip: 'Check payment',
                  icon: const Icon(Icons.refresh),
                  onPressed: _verify)
            ]),
        body: _payment == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/logo.png', height: 64),
                      const SizedBox(height: 16),
                      Text(
                          _provider == 'qrph'
                              ? 'QR Ph'
                              : 'TodaGo wallet top-up',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (_payment != null)
                        Text(_formattedAmount,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 36, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 24),
                      if (_payment != null && !_showLiveQr) ...[
                        Text(
                            'You are about to top up $_formattedAmount to your TodaGo wallet.',
                            textAlign: TextAlign.center),
                        if (!_testMode) ...[
                          const SizedBox(height: 8),
                          const Text(
                              'Your payment app deducts real money when you approve the payment.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12)),
                        ],
                        if (_staticQr) ...[
                          const SizedBox(height: 12),
                          const Text(
                              'This reusable QR is assigned to your TodaGo wallet. Enter the amount yourself in GCash, Maya or your bank app. Your wallet receives the amount actually paid.',
                              textAlign: TextAlign.center),
                        ],
                        if (_provider == 'qrph') ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              onPressed: _opening ||
                                      !_hasAction ||
                                      (_testMode
                                          ? _testAuthorizationUri == null
                                          : !_liveQrAvailable)
                                  ? null
                                  : _testMode
                                      ? () => _authorize(testPayment: true)
                                      : () => _changeQrView(true),
                              icon: _opening
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.arrow_forward),
                              label: const Text('Proceed to Top Up')),
                          if (!_hasAction)
                            const Text(
                                'This top-up is no longer available. Return to your wallet and start a new top-up.',
                                textAlign: TextAlign.center)
                          else if (_testMode && _testAuthorizationUri == null)
                            const Text(
                                'Test authorization is unavailable. Refresh to check again.',
                                textAlign: TextAlign.center)
                          else if (!_testMode && !_liveQrAvailable)
                            const Text(
                                'The QR code is not ready. Refresh to check again.',
                                textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 20),
                      ],
                      if (_provider == 'qrph' && !_testMode && _showLiveQr) ...[
                        const Text('Scan to top up',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                            _staticQr
                                ? 'Scan your QR, enter $_formattedAmount in GCash, Maya or your bank app, and approve the payment.'
                                : 'Scan this QR with GCash, Maya or a QR Ph bank app and approve the payment.',
                            textAlign: TextAlign.center),
                        if (_staticQr) ...[
                          const SizedBox(height: 8),
                          const Text(
                              'Payments to this QR are credited to your TodaGo wallet. The confirmed amount will appear in your transaction history.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(height: 20),
                        if (_liveQrAvailable)
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Container(
                                key: const ValueKey('qrph-payment-code'),
                                padding: const EdgeInsets.all(16),
                                color: Colors.white,
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: _qrImage(
                                      _payment!['qrImageUrl'] as String),
                                ),
                              ),
                            ),
                          )
                        else
                          const Text(
                              'This QR code is no longer available. Return to your wallet and start a new top-up.',
                              textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        const QrPhWallets(),
                        const SizedBox(height: 12),
                        const Text(
                            'On the same phone, take a screenshot and use your payment app\'s scan/upload option if supported.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12)),
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
                          'Your wallet balance updates after payment is confirmed.',
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
