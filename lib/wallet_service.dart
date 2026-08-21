import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class WalletService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/wallet';
  static const _storage = FlutterSecureStorage();

  static Future<String?> _getPassengerToken() async =>
      await _storage.read(key: 'auth_token');

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>?> getWallet() async {
    try {
      final token = await _getPassengerToken();
      final response = await http
          .get(
            Uri.parse(_baseUrl),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['wallet'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> linkAccount({
    required String provider,
    required String accountNumber,
    String? accountName,
  }) async {
    try {
      final token = await _getPassengerToken();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/linked-accounts'),
            headers: _headers(token),
            body: jsonEncode({
              'provider': provider,
              'accountNumber': accountNumber,
              if (accountName != null && accountName.trim().isNotEmpty)
                'accountName': accountName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  static Future<Map<String, dynamic>> unlinkAccount(String provider) async {
    try {
      final token = await _getPassengerToken();
      final response = await http
          .delete(
            Uri.parse('$_baseUrl/linked-accounts/$provider'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  static Future<Map<String, dynamic>> createTopUpCheckout({
    required String provider,
    required double amount,
  }) async {
    try {
      final token = await _getPassengerToken();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/top-up'),
            headers: _headers(token),
            body: jsonEncode({
              'provider': provider,
              'amount': amount,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }
}
