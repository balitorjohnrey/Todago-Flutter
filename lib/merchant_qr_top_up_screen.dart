import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'qr_ph_wallets.dart';
import 'demo_wallet_store.dart';

/// Displays the merchant's existing QR without creating a PayMongo checkout.
/// Top-Up Now returns a demo amount to the caller; real payments are separate.
class MerchantQrTopUpScreen extends StatefulWidget {
  const MerchantQrTopUpScreen({super.key});

  static const qrAsset = 'assets/payments/todago_in_store_qrph.jpg';
  static const amounts = DemoWalletStore.amounts;

  @override
  State<MerchantQrTopUpScreen> createState() => _MerchantQrTopUpScreenState();
}

class _MerchantQrTopUpScreenState extends State<MerchantQrTopUpScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  int _amount = 20;
  bool _showQr = false;
  bool _finished = false;
  bool _autoFinishDemo = true;
  bool _leftDemoScreen = false;
  bool _returnedToDemo = false;
  Route<void>? _fullSizeRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  String get _formattedAmount => '₱${_amount.toStringAsFixed(2)}';

  void _changeView(bool showQr) {
    setState(() {
      _showQr = showQr;
      _leftDemoScreen = false;
      _returnedToDemo = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _topUpNow() {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop(_amount);
  }

  void _finishDemoOnReturn() {
    if (!mounted ||
        !_autoFinishDemo ||
        !_showQr ||
        !_returnedToDemo ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _topUpNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _finished || !_showQr || !_autoFinishDemo) return;
    final ownsVisibleRoute = ModalRoute.of(context)?.isCurrent == true ||
        _fullSizeRoute?.isCurrent == true;
    if (state == AppLifecycleState.paused && ownsVisibleRoute) {
      _leftDemoScreen = true;
    } else if (state == AppLifecycleState.resumed && _leftDemoScreen) {
      // A resume is ONLY a demo trigger, never proof that GCash/Maya was paid.
      _leftDemoScreen = false;
      _returnedToDemo = true;
      if (_fullSizeRoute?.isCurrent == true) {
        Navigator.of(context).pop();
      } else {
        _finishDemoOnReturn();
      }
    }
  }

  Future<void> _copyAmount() async {
    await Clipboard.setData(ClipboardData(text: _amount.toStringAsFixed(2)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Amount copied')),
    );
  }

  Future<void> _viewFullSize() async {
    final route = MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('TodaGo QR Ph')),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                  'Pinch to zoom. Scan with GCash, Maya or your bank app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.backgroundDark)),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: _merchantQr()),
              ),
            ),
          ]),
        ),
      ),
    );
    _fullSizeRoute = route;
    await Navigator.of(context).push<void>(route);
    _fullSizeRoute = null;
    _finishDemoOnReturn();
  }

  Widget _merchantQr() => Image.asset(
        MerchantQrTopUpScreen.qrAsset,
        fit: BoxFit.contain,
        semanticLabel: 'TodaGo merchant in-store QR Ph code',
        errorBuilder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'The QR image could not load. Please return to your wallet.',
              style: TextStyle(color: AppColors.backgroundDark)),
        ),
      );

  Widget _demoNotice() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demo top-up',
                style: TextStyle(
                    color: AppColors.backgroundDark,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
                'Tap Top-Up Now to add demo funds to your passenger wallet. No real payment is required.',
                style: TextStyle(color: AppColors.backgroundDark)),
          ],
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_showQr ? 'QR Ph Top-Up · Demo' : 'Top Up Wallet · Demo'),
          leading: IconButton(
            tooltip: _showQr ? 'Change amount' : 'Back to wallet',
            icon: Icon(_showQr ? Icons.arrow_back : Icons.close),
            onPressed: _showQr
                ? () => _changeView(false)
                : () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('TodaGo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  _showQr
                      ? 'Demo amount to credit'
                      : 'Choose a demo top-up amount',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_formattedAmount,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              if (!_showQr) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: MerchantQrTopUpScreen.amounts
                      .map((amount) => ChoiceChip(
                            label: Text('₱$amount'),
                            selected: _amount == amount,
                            onSelected: (_) => setState(() => _amount = amount),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                const QrPhWallets(),
                const SizedBox(height: 16),
                const Text(
                    'Preview TodaGo’s in-store QR and add demo funds for testing.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                _demoNotice(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _changeView(true),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Proceed to Top Up'),
                ),
              ] else ...[
                _demoNotice(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-finish demo on return'),
                  subtitle: const Text(
                      'Returning from another app adds the selected demo amount. '
                      'This does not verify a real payment.'),
                  value: _autoFinishDemo,
                  onChanged: (value) => setState(() {
                    _autoFinishDemo = value;
                    _leftDemoScreen = false;
                    _returnedToDemo = false;
                  }),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _topUpNow,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Top-Up Now'),
                ),
                const SizedBox(height: 20),
                const Text(
                    'The QR below is a real merchant QR. Paying it through GCash, Maya '
                    'or your bank uses real money and is not needed for this demo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.primary)),
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ColoredBox(
                      key: const ValueKey('todago-merchant-qr'),
                      color: Colors.white,
                      child: _merchantQr(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _viewFullSize,
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('View full-size QR'),
                ),
                TextButton.icon(
                  onPressed: _copyAmount,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy amount'),
                ),
                const SizedBox(height: 8),
                const Text(
                    'Only scan this QR if you intend to make a separate real payment to TodaGo. '
                    'That payment will not automatically credit the demo wallet.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                    'On the same phone, take a screenshot and use your '
                    'payment app’s scan/upload option if supported.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to wallet'),
            ),
          ),
        ),
      );
}
