import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeQrWebViewPlatform extends WebViewPlatform {
  late FakeQrController controller;
  bool finishLoads = true;

  @override
  PlatformWebViewController createPlatformWebViewController(
          PlatformWebViewControllerCreationParams params) =>
      controller = FakeQrController(params, this);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      FakeQrDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
          PlatformWebViewWidgetCreationParams params) =>
      _QrWidget(params);
}

class FakeQrController extends PlatformWebViewController {
  FakeQrController(super.params, this.owner) : super.implementation();
  final FakeQrWebViewPlatform owner;
  late FakeQrDelegate delegate;
  late Uri loaded;
  int loads = 0;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {
    delegate = handler as FakeQrDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loaded = params.uri;
    loads++;
    if (owner.finishLoads) finish();
  }

  void finish() => delegate.onFinish?.call(loaded.toString());
  Uri get completion => loaded.replace(path: '/done.html');
  Future<NavigationDecision> navigate(Uri target,
          {bool mainFrame = true}) async =>
      await delegate.onNavigate!(
          NavigationRequest(url: target.toString(), isMainFrame: mainFrame));
  Future<void> done() async {
    await navigate(completion);
  }

  void fail() => delegate.onError?.call(const WebResourceError(
      errorCode: -2, description: 'Offline', isForMainFrame: true));
}

class FakeQrDelegate extends PlatformNavigationDelegate {
  FakeQrDelegate(super.params) : super.implementation();
  NavigationRequestCallback? onNavigate;
  PageEventCallback? onFinish;
  WebResourceErrorCallback? onError;

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback callback) async {
    onNavigate = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    onFinish = callback;
  }

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    onError = callback;
  }
}

class _QrWidget extends PlatformWebViewWidget {
  _QrWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => Center(
      child: FilledButton(
          onPressed: (params.controller as FakeQrController).done,
          child: const Text('Done')));
}
