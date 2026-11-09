import 'dart:async';
import 'package:flutter/material.dart';

import 'merchant_qr_checkout_screen.dart';
import 'merchant_qr_checkout_session.dart';
import 'qr_ph_wallets.dart';
import 'wallet_service.dart';

class PassengerQrTopUpScreen extends StatefulWidget {
  const PassengerQrTopUpScreen(
      {super.key, this.loadQr = WalletService.getPassengerQr});
  final Future<Map<String, dynamic>> Function() loadQr;
  @override
  State<PassengerQrTopUpScreen> createState() => _PassengerQrTopUpScreenState();
}

class _PassengerQrTopUpScreenState extends State<PassengerQrTopUpScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _qr;
  String? _error;
  String? _baseline;
  bool _initialized = false;
  bool _loading = true;
  bool _checking = false;
  bool _opening = false;
  bool _completed = false;
  bool _closed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<bool> _load() async {
    if (_checking || _closed) return _completed;
    _checking = true;
    try {
      final result = await widget.loadQr();
      if (!mounted) return false;
      if (result['success'] != true ||
          result['testMode'] != false ||
          result['kind'] != 'passenger_pool') {
        throw const FormatException(
            'Unable to load your top-up QR. Please try again.');
      }
      if (result['available'] != true) {
        setState(() {
          _qr = null;
          _error = result['message']?.toString() ??
              'Your top-up QR is being prepared. Please try again later.';
        });
        return false;
      }
      final id = result['qrCodeId']?.toString();
      final checksum = result['qrImageSha256']?.toString() ?? '';
      final session = MerchantQrCheckoutSession(qrCodeId: id);
      if (id == null ||
          result['qrImageUrl'] != session.imageUri.toString() ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
        throw const FormatException(
            'Your QR could not be verified. Please try again.');
      }
      if (_qr != null && _qr!['qrCodeId'] != id) {
        throw const FormatException(
            'Your QR assignment changed. Please contact support.');
      }
      final latest = result['latestPayment'];
      final paymentId = latest is Map ? latest['paymentId']?.toString() : null;
      if (!_initialized) {
        _baseline = paymentId;
        _initialized = true;
      } else if (paymentId != null && paymentId != _baseline) {
        _completed = true;
      }
      setState(() {
        _qr = result;
        _error = null;
      });
      if (_completed &&
          !_opening &&
          ModalRoute.of(context)?.isCurrent == true) {
        _finish('completed');
      }
    } catch (cause) {
      if (mounted) {
        setState(() => _error = cause is FormatException
            ? cause.message
            : 'Unable to check payments. Please try again.');
      }
    } finally {
      _checking = false;
      if (mounted) setState(() => _loading = false);
    }
    return _completed;
  }

  void _finish(String status) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(status);
  }

  Future<void> _open() async {
    if (_qr == null || _opening) return;
    setState(() => _opening = true);
    try {
      final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => MerchantQrCheckoutScreen(
                qrCodeId: _qr!['qrCodeId'] as String,
                imageSha256: _qr!['qrImageSha256'] as String,
                hasConfirmedPayment: _load,
              )));
      if (!mounted) return;
      await _load();
      if (done == true || _completed) {
        _finish(_completed ? 'completed' : 'pending');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
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
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _load)
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 24),
                              Image.asset('assets/logo.png', height: 64),
                              const SizedBox(height: 28),
                              const Text('QR Ph',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 20),
                              const QrPhWallets(),
                              const SizedBox(height: 24),
                              const Text(
                                  'Choose the amount in GCash, Maya or your banking app. Your TodaGo wallet updates automatically after payment is confirmed.',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 28),
                              FilledButton.icon(
                                  onPressed:
                                      _qr != null && !_opening ? _open : null,
                                  icon: const Icon(
                                      Icons.account_balance_wallet_outlined),
                                  label: const Text('Top-Up Now')),
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Text(_error!,
                                        textAlign: TextAlign.center)),
                            ])))),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                    onPressed: () => _finish('pending'),
                    child: const Text('Back to wallet')))),
      );
}
