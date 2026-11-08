import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'merchant_qr_checkout_screen.dart';
import 'qr_ph_wallets.dart';
import 'wallet_service.dart';

class MerchantQrTopUpScreen extends StatefulWidget {
  const MerchantQrTopUpScreen(
      {super.key,
      this.transactionId,
      this.loadConfiguration = WalletService.getMerchantQrConfiguration,
      this.createTopUp = WalletService.createMerchantQrTopUp,
      this.submitReference = WalletService.submitMerchantQrReference,
      this.checkTopUp = WalletService.checkMerchantQrTopUp});

  final String? transactionId;
  final Future<Map<String, dynamic>> Function() loadConfiguration;
  final Future<Map<String, dynamic>> Function(double) createTopUp;
  final Future<Map<String, dynamic>> Function(String, String) submitReference;
  final Future<Map<String, dynamic>> Function(String) checkTopUp;

  @override
  State<MerchantQrTopUpScreen> createState() => _MerchantQrTopUpScreenState();
}

class _MerchantQrTopUpScreenState extends State<MerchantQrTopUpScreen>
    with WidgetsBindingObserver {
  final _reference = TextEditingController();
  final _amountInput = TextEditingController();
  double _amount = 0;
  String? _transactionId;
  String? _error;
  String? _message;
  bool _ready = false;
  bool _loading = true;
  bool _opening = false;
  bool _submitting = false;
  bool _checking = false;
  bool _showReference = false;
  bool _completed = false;
  bool _closed = false;
  bool _expired = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transactionId = widget.transactionId;
    _showReference = _transactionId != null;
    _initialize();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_showReference && !_expired) _check();
    });
  }

  Future<void> _initialize() async {
    try {
      final result = await widget.loadConfiguration();
      if (!mounted) return;
      setState(() {
        _ready = result['success'] == true && result['available'] == true;
        _loading = false;
        if (!_ready)
          _error =
              'QR Ph top-ups are not available yet. Please try again later.';
      });
      if (_transactionId != null) await _check();
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Unable to load top-ups. Please try again.';
        });
    }
  }

  bool _apply(Map<String, dynamic> result) {
    if (result['success'] != true ||
        result['payment'] is! Map ||
        result['transactionId'] is! String ||
        result['testMode'] != false) {
      setState(() => _error = result['message']?.toString() ??
          'Unable to check this top-up. Please try again.');
      return false;
    }
    final payment = result['payment'] as Map;
    final amount = double.tryParse('${payment['amount']}');
    if (payment['kind'] != 'merchant_qr' ||
        amount == null ||
        !amount.isFinite ||
        amount < 20 ||
        amount > 50000) {
      setState(() =>
          _error = 'This top-up is unavailable. Please return to your wallet.');
      return false;
    }
    setState(() {
      _transactionId = result['transactionId'] as String;
      _amount = amount;
      _amountInput.text = amount.toStringAsFixed(2);
      _completed = _completed || result['status'] == 'completed';
      _expired = {'cancelled', 'failed'}.contains(result['status']);
      _error = null;
      _message = _expired
          ? 'This top-up has expired. Contact support if you have paid.'
          : result['message']?.toString() ?? _message;
      if (_reference.text.isEmpty && payment['reference'] is String) {
        _reference.text = payment['reference'] as String;
      }
    });
    _finishIfCompleted();
    return true;
  }

  void _finishIfCompleted() {
    if (_completed &&
        !_closed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      _closed = true;
      Navigator.of(context).pop('completed');
    }
  }

  Future<void> _topUpNow() async {
    if (_opening || !_ready || _expired || _amount < 20 || _amount > 50000)
      return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      if (_transactionId == null) {
        final result = await widget.createTopUp(_amount);
        if (!mounted || !_apply(result) || _completed) return;
      }
      if (!mounted) return;
      final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => MerchantQrCheckoutScreen(amount: _amount),
      ));
      if (!mounted) return;
      setState(() => _showReference = done == true || _showReference);
      _finishIfCompleted();
      if (_showReference && !_completed) await _check();
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Unable to open the QR page. Please try again.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _transactionId == null || _expired || !_ready) return;
    if (_reference.text.trim().isEmpty) {
      setState(() => _error =
          'Enter the transaction reference from your payment receipt.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result =
          await widget.submitReference(_transactionId!, _reference.text.trim());
      if (mounted) _apply(result);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Unable to submit the reference. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _check() async {
    if (_checking || _submitting || _transactionId == null || _closed) return;
    _checking = true;
    try {
      final result = await widget.checkTopUp(_transactionId!);
      if (mounted) _apply(result);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Unable to check payment. Please try again.');
    } finally {
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showReference) _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reference.dispose();
    _amountInput.dispose();
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
                onPressed: () => Navigator.of(context).pop('pending')),
            actions: [
              if (_transactionId != null)
                IconButton(
                    tooltip: 'Check payment',
                    icon: const Icon(Icons.refresh),
                    onPressed: _check)
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
                              const SizedBox(height: 16),
                              Image.asset('assets/logo.png', height: 64),
                              const SizedBox(height: 24),
                              const Text('QR Ph',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              if (_showReference)
                                Text('₱${_amount.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800)),
                              const SizedBox(height: 24),
                              if (!_showReference) ...[
                                TextField(
                                  key: const ValueKey('top-up-amount'),
                                  controller: _amountInput,
                                  enabled: !_opening && _transactionId == null,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    TextInputFormatter.withFunction(
                                        (oldValue, newValue) =>
                                            RegExp(r'^\d{0,5}(?:\.\d{0,2})?$')
                                                    .hasMatch(newValue.text)
                                                ? newValue
                                                : oldValue)
                                  ],
                                  onChanged: (value) => setState(() =>
                                      _amount = double.tryParse(value) ?? 0),
                                  decoration: const InputDecoration(
                                      labelText: 'Amount to top up',
                                      prefixText: '₱ ',
                                      hintText: '0.00',
                                      helperText:
                                          'Minimum ₱20 · Maximum ₱50,000',
                                      border: OutlineInputBorder()),
                                ),
                                const SizedBox(height: 24),
                                const QrPhWallets(),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                    onPressed: _ready &&
                                            !_opening &&
                                            !_expired &&
                                            _amount >= 20 &&
                                            _amount <= 50000
                                        ? _topUpNow
                                        : null,
                                    icon: const Icon(
                                        Icons.account_balance_wallet_outlined),
                                    label: const Text('Top-Up Now')),
                                const SizedBox(height: 16),
                                const Text(
                                    'Pay the exact amount using your bank or e-wallet. Then tap Done and enter your receipt’s transaction reference.',
                                    textAlign: TextAlign.center),
                              ] else ...[
                                const Text('Payment reference',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Enter the transaction reference from your bank or e-wallet receipt. Your balance updates after the payment is confirmed.'),
                                const SizedBox(height: 16),
                                TextField(
                                    controller: _reference,
                                    enabled: !_submitting && !_expired,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    maxLength: 100,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                        labelText: 'Transaction reference',
                                        border: OutlineInputBorder())),
                                const SizedBox(height: 12),
                                FilledButton(
                                    onPressed:
                                        _ready && !_submitting && !_expired
                                            ? _submit
                                            : null,
                                    child: Text(_submitting
                                        ? 'Checking…'
                                        : 'Submit reference')),
                                TextButton(
                                    onPressed: _ready && !_opening && !_expired
                                        ? _topUpNow
                                        : null,
                                    child: const Text('View QR again')),
                                const SizedBox(height: 12),
                                Text(
                                    _expired
                                        ? 'Top-up expired'
                                        : 'Pending payment confirmation',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                              if (_message != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(_message!,
                                        textAlign: TextAlign.center)),
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(_error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: AppColors.error))),
                            ])))),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                    onPressed: () => Navigator.of(context).pop('pending'),
                    child: const Text('Back to wallet')))),
      );
}
