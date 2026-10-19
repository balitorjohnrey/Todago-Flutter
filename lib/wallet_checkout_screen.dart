import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'app_theme.dart';
import 'wallet_return_links.dart';
import 'wallet_service.dart';
import 'payment_app_links.dart';

class WalletCheckoutScreen extends StatefulWidget {
  const WalletCheckoutScreen(
      {super.key,
      required this.checkoutUrl,
      required this.transactionId,
      this.testMode = false,
      this.providerAuthorization = false,
      this.providerLabel = 'payment provider'});
  final String checkoutUrl;
  final String transactionId;
  final bool testMode;
  final bool providerAuthorization;
  final String providerLabel;

  @override
  State<WalletCheckoutScreen> createState() => _WalletCheckoutScreenState();
}

class _WalletCheckoutScreenState extends State<WalletCheckoutScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  Timer? _timer;
  StreamSubscription<Uri>? _links;
  bool _checking = false;
  bool _returned = false;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _links = WalletReturnLinks.stream.listen((_) => _onReturn());
    final uri = Uri.tryParse(widget.checkoutUrl);
    if (uri?.scheme != 'https' ||
        uri!.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (!widget.providerAuthorization &&
            uri.host != 'checkout.paymongo.com')) {
      _error =
          'The checkout link is invalid. Please return to your wallet and try again.';
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onPageStarted: (url) {
          if (_isReturnUrl(Uri.tryParse(url))) _onReturn();
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() => _error =
                'The payment page could not load. Check your connection and try again.');
          }
        },
        onNavigationRequest: (request) async {
          final target = Uri.tryParse(request.url);
          if (target == null) return NavigationDecision.prevent;
          if (_isReturnUrl(target)) {
            _onReturn();
            return NavigationDecision.prevent;
          }
          if (['https', 'about'].contains(target.scheme)) {
            return NavigationDecision.navigate;
          }
          await _openPaymentApp(target);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(uri);
    _timer =
        Timer.periodic(const Duration(seconds: 4), (_) => _verifyPayment());
  }

  bool _isReturnUrl(Uri? uri) {
    if (uri == null) return false;
    return WalletReturnLinks.isWalletReturn(uri) ||
        (uri.scheme == 'https' &&
            uri.host == 'todago-backend-production.up.railway.app' &&
            uri.path == '/api/wallet/paymongo/return' &&
            uri.queryParameters['transactionId'] == widget.transactionId);
  }

  void _onReturn() {
    if (!mounted) return;
    setState(() {
      _returned = true;
      _error = null;
    });
    _verifyPayment();
  }

  Future<void> _openPaymentApp(Uri uri) async {
    final target = paymentAppUri(uri);
    if (target == null) return;
    try {
      final opened =
          await launchUrl(target, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showAppError();
    } catch (_) {
      if (mounted) _showAppError();
    }
  }

  void _showAppError() =>
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'The payment app could not open. Install it or choose another payment method.'),
      ));

  Future<void> _verifyPayment() async {
    if (_checking || !mounted) return;
    _checking = true;
    final result = await WalletService.checkTopUp(widget.transactionId);
    _checking = false;
    if (!mounted) return;
    final status = result['status'];
    if (result['success'] == true &&
        {'completed', 'failed', 'cancelled'}.contains(status)) {
      Navigator.of(context).pop(status as String);
    } else if (_returned) {
      setState(() => _error =
          result['success'] == true ? null : result['message']?.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifyPayment();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _links?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.providerAuthorization
              ? 'Authorize with ${widget.providerLabel}'
              : widget.testMode
                  ? 'Top up • Test checkout'
                  : 'Top up wallet'),
          leading: IconButton(
              tooltip: 'Back to wallet',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop('pending')),
          actions: [
            IconButton(
                tooltip: 'Check payment',
                icon: const Icon(Icons.refresh),
                onPressed: _verifyPayment)
          ],
        ),
        body: Column(children: [
          if (_progress < 100 && !_returned && _error == null)
            LinearProgressIndicator(
                value: _progress / 100, color: AppColors.primary),
          Expanded(
              child: _returned || _error != null
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_returned) const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(_error ?? 'Waiting for payment confirmation',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        const Text(
                            'Your balance will update after payment is confirmed. You can return to your wallet while we check.',
                            textAlign: TextAlign.center),
                        if (!_returned && _controller != null)
                          TextButton(
                              onPressed: () {
                                setState(() => _error = null);
                                _controller!.reload();
                              },
                              child: const Text('Reload checkout')),
                      ]),
                    ))
                  : WebViewWidget(controller: _controller!)),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () => Navigator.of(context).pop('pending'),
                        child: const Text('Back to wallet')),
                  ))),
        ]),
      );
}
