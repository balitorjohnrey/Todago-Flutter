import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'driver_auth_service.dart';
import 'admin_auth_service.dart';

class DriverWalletService {
  static const _base = 'https://todago-backend-production.up.railway.app/api';

  static String newRequestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<Map<String, dynamic>> _request(String path,
      {bool admin = false, Map<String, dynamic>? body}) async {
    try {
      final token = admin
          ? await AdminAuthService.getPayoutToken()
          : await DriverAuthService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      };
      final uri = Uri.parse('$_base/$path');
      final response = await (body == null
              ? http.get(uri, headers: headers)
              : http.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 20));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'message':
            'Connection interrupted. Refresh your requests before trying again.'
      };
    }
  }

  static Future<Map<String, dynamic>> wallet() => _request('driver/wallet');
  static Future<Map<String, dynamic>> requestCashOut(
          Map<String, dynamic> body) =>
      _request('driver/wallet/cash-outs', body: body);
  static Future<Map<String, dynamic>> cancel(String id) =>
      _request('driver/wallet/cash-outs/${Uri.encodeComponent(id)}/cancel',
          body: {});
  static Future<Map<String, dynamic>> adminRequests({bool history = false}) =>
      _request('admin/driver-cashouts?view=${history ? 'history' : 'active'}',
          admin: true);
  static Future<Map<String, dynamic>> review(
          String id, Map<String, dynamic> body) =>
      _request('admin/driver-cashouts/${Uri.encodeComponent(id)}/review',
          admin: true, body: body);
}
