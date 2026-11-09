import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_theme.dart';
import 'merchant_qr_checkout_session.dart';
import 'qr_gallery.dart';

/// Opens only TodaGo's standalone QR page, entirely inside the application.
class MerchantQrCheckoutScreen extends StatefulWidget {
  const MerchantQrCheckoutScreen(
      {super.key,
      this.amount,
      this.qrCodeId,
      this.imageSha256,
      this.hasConfirmedPayment});
  final double? amount;
  final String? qrCodeId;
  final String? imageSha256;
  final Future<bool> Function()? hasConfirmedPayment;

  @override
  State<MerchantQrCheckoutScreen> createState() =>
      _MerchantQrCheckoutScreenState();
}

class _MerchantQrCheckoutScreenState extends State<MerchantQrCheckoutScreen>
    with WidgetsBindingObserver {
  late final MerchantQrCheckoutSession _session;
  WebViewController? _controller;
  bool _ready = false;
  bool _finished = false;
  int _progress = 0;
  String? _error;
  Timer? _timer;
  bool _checking = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _session = MerchantQrCheckoutSession(
        amount: widget.amount, qrCodeId: widget.qrCodeId);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkPayment());
    _loadPage();
  }

  Future<void> _checkPayment() async {
    if (!_ready ||
        _finished ||
        _checking ||
        widget.hasConfirmedPayment == null) {
      return;
    }
    _checking = true;
    try {
      final paid = await widget.hasConfirmedPayment!();
      if (paid &&
          mounted &&
          !_finished &&
          ModalRoute.of(context)?.isCurrent == true) {
        _finished = true;
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      // A failed balance check must leave the QR usable and never imply credit.
    } finally {
      _checking = false;
    }
  }

  Future<void> _download(String message) async {
    if (!_ready ||
        _finished ||
        _downloading ||
        !mounted ||
        widget.qrCodeId == null ||
        widget.imageSha256 == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    try {
      final data = jsonDecode(message);
      if (data is! Map ||
          data['type'] != 'download' ||
          data['session'] != _session.token ||
          data['qrId'] != widget.qrCodeId) {
        return;
      }
      _downloading = true;
      await QrGallery.save(widget.qrCodeId!, widget.imageSha256!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('QR saved to Photos. Upload it in GCash or Maya.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Unable to save the QR. Check your connection and try again.')));
      }
    } finally {
      _downloading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPayment();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        if (_session.qrCodeId != null) {
          await controller.addJavaScriptChannel('TodaGoQr',
              onMessageReceived: (message) => _download(message.message));
        }
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
