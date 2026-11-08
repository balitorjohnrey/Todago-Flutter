import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_theme.dart';
import 'merchant_qr_checkout_session.dart';

/// Opens only TodaGo's standalone QR page, entirely inside the application.
class MerchantQrCheckoutScreen extends StatefulWidget {
  const MerchantQrCheckoutScreen({super.key, required this.amount});
  final double amount;

  @override
  State<MerchantQrCheckoutScreen> createState() =>
      _MerchantQrCheckoutScreenState();
}

class _MerchantQrCheckoutScreenState extends State<MerchantQrCheckoutScreen> {
  late final MerchantQrCheckoutSession _session;
  WebViewController? _controller;
  bool _ready = false;
  bool _finished = false;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = MerchantQrCheckoutSession(amount: widget.amount);
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _ready = false;
      _progress = 0;
      _error = null;
    });
    try {
      if (_controller == null) {
        final controller = WebViewController();
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        await controller.setBackgroundColor(Colors.white);
        await controller.setNavigationDelegate(NavigationDelegate(
          onProgress: (value) {
            if (mounted && !_finished) setState(() => _progress = value);
          },
          onPageFinished: (url) {
            if (!mounted || _finished || _error != null) return;
            if (_session.isPage(Uri.tryParse(url))) {
              setState(() {
                _ready = true;
                _progress = 100;
              });
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _showLoadError();
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (!request.isMainFrame) return NavigationDecision.prevent;
            if (_session.isCompletion(uri)) {
              if (_ready &&
                  !_finished &&
                  mounted &&
                  ModalRoute.of(context)?.isCurrent == true) {
                _finished = true;
                Navigator.of(context).pop(true);
              }
              return NavigationDecision.prevent;
            }
            // No external browser, e-wallet apps, arbitrary pages or deep links.
            return _session.isPage(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ));
        if (!mounted) return;
        setState(() => _controller = controller);
      }
      await _controller!.loadRequest(_session.pageUri);
    } catch (_) {
      _showLoadError();
    }
  }

  void _showLoadError() {
    if (!mounted || _finished) return;
    setState(() {
      _ready = false;
      _error =
          'The QR page could not load. Check your connection and try again.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('QR Ph'),
          leading: IconButton(
            tooltip: 'Back to top-up',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: SafeArea(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded, size: 40),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _loadPage, child: const Text('Try again')),
                    ]),
                  ),
                )
              : Column(children: [
                  if (_progress < 100)
                    LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress / 100,
                        color: AppColors.primary),
                  if (_controller != null)
                    Expanded(child: WebViewWidget(controller: _controller!)),
                ]),
        ),
      );
}
