import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'app_theme.dart';
import 'identity_verification_service.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({
    super.key,
    required this.verificationUrl,
    this.statusToken,
    this.callbackUrl,
    this.checkStatus,
    this.verificationContent,
  });

  final Uri verificationUrl;
  final String? statusToken;
  final String? callbackUrl;
  final Future<Map<String, dynamic>> Function()? checkStatus;
  final Widget? verificationContent;

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  Timer? _timer;
  bool _checking = false;
  bool _approved = false;
  bool _finished = false;
  int _progress = 0;
  String? _status;
  String? _statusError;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.verificationContent == null) _initWebView();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
    unawaited(_checkStatus());
  }

  void _initWebView() {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]
            .contains(defaultTargetPlatform)) {
      _pageError =
          'Identity verification is available in the TodaGo mobile app.';
      return;
    }
    _controller = WebViewController(onPermissionRequest: _requestPermissions)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onNavigationRequest: (request) {
          if (!mounted) return NavigationDecision.prevent;
          final target = Uri.tryParse(request.url);
          if (target == null) return NavigationDecision.prevent;
          if (_isCallback(target)) {
            setState(() => _finished = true);
            unawaited(_checkStatus());
            return NavigationDecision.prevent;
          }
          // Verification never hands links to the browser or another app.
          return ['https', 'about', 'blob', 'data'].contains(target.scheme)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() => _pageError =
                'The verification page could not load. Please try again.');
          }
        },
      ))
      ..loadRequest(widget.verificationUrl);
  }

  bool _isCallback(Uri target) {
    final callback =
        Uri.tryParse(widget.callbackUrl ?? 'todago://kyc-complete');
    return callback != null &&
        target.scheme == callback.scheme &&
        target.host == callback.host &&
        target.path == callback.path;
  }

  Future<void> _requestPermissions(WebViewPermissionRequest request) async {
    final permissions = <Permission>[];
    for (final type in request.types) {
      if (type == WebViewPermissionResourceType.camera) {
        permissions.add(Permission.camera);
      } else if (type == WebViewPermissionResourceType.microphone) {
        permissions.add(Permission.microphone);
      } else {
        await request.deny();
        return;
      }
    }
    // WKWebView presents its native permission prompt using Info.plist.
    final granted = defaultTargetPlatform != TargetPlatform.android ||
        (await permissions.request())
            .values
            .every((status) => status.isGranted);
    if (!mounted || !granted) {
      await request.deny();
      if (mounted) {
        setState(() => _pageError =
            'Camera access is needed for your ID and selfie. Allow it in app settings, then retry.');
      }
      return;
    }
    await request.grant();
  }

  Future<void> _checkStatus() async {
    if (_checking || _approved || !mounted) return;
    setState(() => _checking = true);
    try {
      final identity = await (widget.checkStatus?.call() ??
          IdentityVerificationService.checkStatus(widget.statusToken));
      if (!mounted) return;
      setState(() {
        _status = identity['status'] as String?;
        _approved = identity['isVerified'] == true && _status == 'approved';
        _statusError = null;
      });
      if (_approved) _timer?.cancel();
    } catch (error) {
      if (mounted) {
        setState(() => _statusError = error is StateError
            ? error.message.toString()
            : 'Unable to check verification. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String get _message {
    if (_approved) return 'Your ID and face verification passed.';
    if (_statusError != null) return _statusError!;
    if (_status == 'needs_review') {
      return 'Your verification is being reviewed. You can return and check again later.';
    }
    if (['declined', 'failed', 'expired', 'abandoned', 'kyc_expired']
        .contains(_status)) {
      return 'Verification has not passed. Return and sign in again to retry.';
    }
    if (_finished) return 'Verification submitted. Waiting for your result…';
    return 'Complete your ID and selfie verification here in TodaGo.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Identity verification'),
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: _approved ? 'Back to TodaGo' : 'Close verification',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(_approved),
        ),
        actions: [
          IconButton(
            tooltip: 'Check verification status',
            onPressed: _checking || _approved ? null : _checkStatus,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: SafeArea(
          child: Column(children: [
        if (!_approved && !_finished && _progress < 100 && _controller != null)
          LinearProgressIndicator(value: _progress / 100),
        Expanded(
            child: _approved
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_user_rounded,
                          color: AppColors.success, size: 80),
                      SizedBox(height: 20),
                      Text('Verification passed',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.backgroundDark)),
                    ]),
                  ))
                : _pageError != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_pageError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.backgroundDark)),
                                  if (_controller != null)
                                    TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _pageError = null;
                                            _progress = 0;
                                          });
                                          _controller!.loadRequest(
                                              widget.verificationUrl);
                                        },
                                        child:
                                            const Text('Retry verification')),
                                ])))
                    : _finished
                        ? const Center(child: CircularProgressIndicator())
                        : widget.verificationContent ??
                            (_controller == null
                                ? const SizedBox.shrink()
                                : WebViewWidget(controller: _controller!))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.backgroundDark)),
                const SizedBox(height: 12),
                if (_approved)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to TodaGo'),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.backgroundDark),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Return and verify later'),
                  ),
              ],
            )),
      ])),
    );
  }
}
