import 'dart:async';
import 'package:flutter/material.dart';
import 'driver_wallet_service.dart';
import 'payment_method_logo.dart';

String cashOutMoney(dynamic value) =>
    '₱${(num.tryParse('$value') ?? 0).toStringAsFixed(2)}';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen(
      {super.key,
      this.fetchWallet = DriverWalletService.wallet,
      this.createCashOut = DriverWalletService.requestCashOut});
  final Future<Map<String, dynamic>> Function() fetchWallet;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)
      createCashOut;
  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _wallet;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _refreshing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    final result = await widget.fetchWallet();
    _refreshing = false;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result['success'] == true ? null : result['message']?.toString();
      if (result['wallet'] is Map) {
        _wallet = Map<String, dynamic>.from(result['wallet'] as Map);
      }
    });
  }

  Future<void> _request() async {
    final amount = TextEditingController(text: '50');
    final name = TextEditingController();
    final number = TextEditingController();
    final key = DriverWalletService.newRequestKey();
    final form = GlobalKey<FormState>();
    var provider = 'gcash';
    var sending = false;
    String? error;
    try {
      final route = DialogRoute<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
              builder: (context, change) => PopScope(
                  canPop: !sending,
                  child: AlertDialog(
                    title: const Text('Cash out to e-wallet'),
                    content: SingleChildScrollView(
                        child: Form(
                            key: form,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      'Available: ${cashOutMoney(_wallet?['available'])}\nMinimum ₱50 • TodaGo fee ₱0',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                      initialValue: provider,
                                      decoration: const InputDecoration(
                                          labelText: 'E-wallet'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'gcash',
                                            child: Text('GCash')),
                                        DropdownMenuItem(
                                            value: 'maya', child: Text('Maya'))
                                      ],
                                      onChanged: sending
                                          ? null
                                          : (value) =>
                                              change(() => provider = value!)),
                                  TextFormField(
                                      controller: amount,
                                      enabled: !sending,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Amount (PHP)'),
                                      validator: (value) {
                                        final parsed =
                                            double.tryParse(value ?? '');
                                        return parsed == null ||
                                                parsed < 50 ||
                                                parsed > 50000 ||
                                                !RegExp(r'^\d+(\.\d{1,2})?$')
                                                    .hasMatch(value ?? '')
                                            ? 'Enter ₱50–₱50,000, up to 2 decimal places'
                                            : null;
                                      }),
                                  TextFormField(
                                      controller: name,
                                      enabled: !sending,
                                      maxLength: 120,
                                      decoration: const InputDecoration(
                                          labelText: 'E-wallet account name'),
                                      validator: (value) => (value
                                                      ?.trim()
                                                      .length ??
                                                  0) <
                                              2
                                          ? 'Enter the registered account name'
                                          : null),
                                  TextFormField(
                                      controller: number,
                                      enabled: !sending,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 11,
                                      decoration: const InputDecoration(
                                          labelText: 'Mobile number',
                                          hintText: '09XXXXXXXXX'),
                                      validator: (value) => RegExp(r'^09\d{9}$')
                                              .hasMatch(value ?? '')
                                          ? null
                                          : 'Enter an 11-digit number starting 09'),
                                  const Text(
                                      'TodaGo staff sends this payout manually. Verify your details. The amount is reserved until paid or cancelled.',
                                      style: TextStyle(fontSize: 12)),
                                  if (error != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(error!,
                                            style: const TextStyle(
                                                color: Colors.red))),
                                ]))),
                    actions: [
                      TextButton(
                          onPressed: sending
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text('Close')),
                      FilledButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  if (!form.currentState!.validate()) return;
                                  change(() {
                                    sending = true;
                                    error = null;
                                  });
                                  final result = await widget.createCashOut({
                                    'amount': amount.text.trim(),
                                    'provider': provider,
                                    'accountName': name.text.trim(),
                                    'accountNumber': number.text.trim(),
                                    'requestKey': key
                                  });
                                  if (!dialogContext.mounted) return;
                                  if (result['success'] == true) {
                                    Navigator.pop(dialogContext);
                                    await _load();
                                  } else {
                                    change(() {
                                      sending = false;
                                      error = result['message']?.toString();
                                    });
                                  }
                                },
                          child: Text(
                              sending ? 'Requesting…' : 'Request cash-out')),
                    ],
                  ))));
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      amount.dispose();
      name.dispose();
      number.dispose();
    }
  }

  Future<void> _cancel(String id) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Cancel cash-out?'),
                content: const Text(
                    'The reserved amount will return to your available balance.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Keep request')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Cancel request'))
                ]));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final result = await DriverWalletService.cancel(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] != true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${result['message']}')));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final requests = (_wallet?['requests'] as List? ?? []).whereType<Map>();
    return Scaffold(
        appBar: AppBar(title: const Text('Driver wallet'), actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const Text('Available cashless earnings',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text(cashOutMoney(_wallet?['available']),
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w800)),
                  Text(
                      'Reserved: ${cashOutMoney(_wallet?['reserved'])} • Paid out: ${cashOutMoney(_wallet?['paid'])}'),
                  const SizedBox(height: 12),
                  const Text(
                      'Cash fares are already received by you and are excluded. Only completed, confirmed cashless fares can be withdrawn.'),
                  const SizedBox(height: 8),
                  const Text(
                      'Wallet payments are credited when you confirm payment and complete the trip. This balance refreshes every 5 seconds.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _wallet == null ||
                              _wallet?['cashOutEnabled'] == false ||
                              _error != null ||
                              (num.tryParse('${_wallet?['available']}') ?? 0) <
                                  50
                          ? null
                          : _request,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Cash out • Minimum ₱50')),
                  const SizedBox(height: 8),
                  const Text(
                      'Manual GCash / Maya payout • TodaGo fee ₱0. Processing is handled by staff, not instant.'),
                  if (_wallet?['testMode'] == true)
                    const Text('Test balances cannot be withdrawn.',
                        style: TextStyle(color: Colors.orange)),
                  const SizedBox(height: 24),
                  const Text('Cash-out history',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  if (requests.isEmpty)
                    const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text('No cash-out requests yet.')),
                  for (final row in requests)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    PaymentMethodLogo(
                                        provider: '${row['provider']}',
                                        width: 70),
                                    const Spacer(),
                                    Text(cashOutMoney(row['amount']),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))
                                  ]),
                                  Text(
                                      '${row['account_name']} • ****${'${row['account_number']}'.length >= 4 ? '${row['account_number']}'.substring('${row['account_number']}'.length - 4) : ''}'),
                                  Text('Status: ${row['status']}'),
                                  Text('${row['created_at']}'),
                                  if (row['payment_reference'] != null)
                                    Text(
                                        'Transfer reference: ${row['payment_reference']}'),
                                  if (row['review_note'] != null)
                                    Text('${row['review_note']}'),
                                  if (row['status'] == 'pending')
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () =>
                                                _cancel('${row['cashout_id']}'),
                                        child: const Text('Cancel request')),
                                ]))),
                ])));
  }
}
