import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'driver_wallet_service.dart';
import 'driver_wallet_screen.dart' show cashOutMoney;
import 'admin_auth_service.dart';
import 'splash_screen.dart';

class AdminCashoutsScreen extends StatefulWidget {
  const AdminCashoutsScreen({super.key, this.fetchRequests, this.submitReview});
  final Future<Map<String, dynamic>> Function(bool history)? fetchRequests;
  final Future<Map<String, dynamic>> Function(
      String id, Map<String, dynamic> body)? submitReview;
  @override
  State<AdminCashoutsScreen> createState() => _AdminCashoutsScreenState();
}

class _AdminCashoutsScreenState extends State<AdminCashoutsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _history = false;
  bool _refreshing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_busy) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    final history = _history;
    final result = await (widget.fetchRequests?.call(history) ??
        DriverWalletService.adminRequests(history: history));
    _refreshing = false;
    if (!mounted) return;
    if (history != _history) {
      await _load();
      return;
    }
    setState(() {
      _loading = false;
      _error = result['success'] == true ? null : result['message']?.toString();
      if (result['success'] == true) {
        _requests = (result['requests'] as List? ?? [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
    });
  }

  Future<void> _review(Map<String, dynamic> row, String action) async {
    final reference = TextEditingController();
    final note = TextEditingController();
    var confirmed = false;
    final dialog = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, change) => AlertDialog(
                  title: Text(action == 'paid'
                      ? 'Confirm money already sent'
                      : action == 'processing'
                          ? 'Start manual payout'
                          : 'Reject request'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${row['driver_name']}\n${cashOutMoney(row['amount'])} → ${'${row['provider']}'.toUpperCase()}\n${row['account_name']}\n${row['account_number']}'),
                        const SizedBox(height: 12),
                        Text(action == 'paid'
                            ? 'Only record a successful transfer verified in your e-wallet. A screenshot or pending transfer is not confirmation.'
                            : action == 'processing'
                                ? 'This reserves the request for payment. TodaGo does not send funds automatically. Check your e-wallet history before sending to prevent duplicate payments.'
                                : 'Reject only if no payout has been sent. The reserved balance will be released.'),
                        if (action == 'paid')
                          TextField(
                              controller: reference,
                              decoration: const InputDecoration(
                                  labelText: 'Actual transfer reference'),
                              maxLength: 100),
                        if (action != 'processing')
                          TextField(
                              controller: note,
                              decoration: InputDecoration(
                                  labelText: action == 'rejected'
                                      ? 'Reason (required)'
                                      : 'Note (optional)'),
                              maxLength: 300),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: confirmed,
                            onChanged: (value) =>
                                change(() => confirmed = value ?? false),
                            title: Text(action == 'paid'
                                ? 'I sent the full amount and verified success. Any transfer fee is covered by TodaGo.'
                                : action == 'processing'
                                    ? 'I will handle this payout manually and check for existing transfers.'
                                    : 'No payout was sent for this request.')),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Back')),
                    FilledButton(
                        onPressed: confirmed
                            ? () => Navigator.pop(dialogContext, true)
                            : null,
                        child: Text(action == 'paid'
                            ? 'Record paid'
                            : action == 'processing'
                                ? 'Start processing'
                                : 'Reject request'))
                  ],
                )));
    final approve = await Navigator.of(context).push(dialog);
    await dialog.completed;
    final ref = reference.text.trim();
    final reviewNote = note.text.trim();
    reference.dispose();
    note.dispose();
    if (approve != true || !mounted) return;
    if ((action == 'paid' && !RegExp(r'^[a-zA-Z0-9-]{5,100}$').hasMatch(ref)) ||
        (action == 'rejected' && reviewNote.length < 3)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enter a valid transfer reference or rejection reason.')));
      return;
    }
    setState(() => _busy = true);
    final body = {
      'action': action,
      'reference': ref,
      'note': reviewNote,
      'confirmedNotSent': action == 'rejected'
    };
    final result =
        await (widget.submitReview?.call('${row['cashout_id']}', body) ??
            DriverWalletService.review('${row['cashout_id']}', body));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true
            ? 'Request updated.'
            : '${result['message']}')));
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Payout admin'),
          actions: [
            IconButton(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh)),
            IconButton(
                tooltip: 'Sign out',
                onPressed: _busy
                    ? null
                    : () async {
                        await AdminAuthService.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const SplashScreen()),
                            (_) => false);
                      },
                icon: const Icon(Icons.logout)),
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const Text('Manual e-wallet payouts',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                    'Minimum ₱50 • Driver fee ₱0. Staff must send money from an independently funded e-wallet and cover any provider fees. Funds held in a restricted PayMongo wallet are not accessible through this screen.'),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('Pending payouts'),
                          icon: Icon(Icons.pending_actions)),
                      ButtonSegment(
                          value: true,
                          label: Text('History'),
                          icon: Icon(Icons.history)),
                    ],
                    selected: {
                      _history
                    },
                    onSelectionChanged: _busy
                        ? null
                        : (values) {
                            setState(() {
                              _history = values.first;
                              _requests = [];
                              _loading = true;
                            });
                            _load();
                          }),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_requests.isEmpty && _error == null)
                  const Text('No requests yet.'),
                for (final row in _requests)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${row['driver_name']} • ${cashOutMoney(row['amount'])}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18)),
                                SelectableText(
                                    '${'${row['provider']}'.toUpperCase()} • ${row['account_name']}\n${row['account_number']}'),
                                Text('Status: ${row['status']}'),
                                Text('Requested: ${row['created_at']}'),
                                Text('Request: ${row['cashout_id']}',
                                    style: const TextStyle(fontSize: 11)),
                                if (row['payment_reference'] != null)
                                  SelectableText(
                                      'Transfer reference: ${row['payment_reference']}'),
                                if (row['review_note'] != null)
                                  Text('${row['review_note']}'),
                                if (['pending', 'processing']
                                    .contains(row['status']))
                                  Wrap(spacing: 8, children: [
                                    TextButton.icon(
                                        onPressed: () => Clipboard.setData(
                                            ClipboardData(
                                                text:
                                                    '${row['account_number']}')),
                                        icon: const Icon(Icons.copy),
                                        label: const Text('Copy number')),
                                    if (row['status'] == 'pending') ...[
                                      FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () =>
                                                  _review(row, 'processing'),
                                          child:
                                              const Text('Start processing')),
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(row, 'rejected'),
                                          child: const Text('Reject')),
                                    ],
                                    if (row['status'] == 'processing')
                                      FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(row, 'paid'),
                                          child: const Text(
                                              'Record successful payment')),
                                    if (row['status'] == 'processing')
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(row, 'rejected'),
                                          child:
                                              const Text('Payment not sent')),
                                  ]),
                              ]))),
              ])));
}
