import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AdminAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? admin;

  AdminAuthResponse({
    required this.success,
    this.message,
    this.token,
    this.admin,
  });
}

class AdminAuthService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/admin';
  static const _storage = FlutterSecureStorage();
  static const _adminTokenKey = 'admin_auth_token';
  static const _adminDataKey = 'admin_data';

  static Future<AdminAuthResponse> login({required String secret}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'secret': secret.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        await _storage.write(key: _adminTokenKey, value: data['token']);
        if (data['admin'] != null) {
          await _storage.write(
            key: _adminDataKey,
            value: jsonEncode(data['admin']),
          );
        }
        return AdminAuthResponse(
          success: true,
          message: data['message'] ?? 'Admin login successful',
          token: data['token'],
          admin: data['admin'],
        );
      }
      return AdminAuthResponse(
        success: false,
        message: data['message'] ?? 'Invalid admin secret',
      );
    } catch (_) {
      return AdminAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  static Future<String?> getToken() => _storage.read(key: _adminTokenKey);

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> fetchStats() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/stats'), headers: await _headers())
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return data['stats'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchIndependentDrivers() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/drivers/independent'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final drivers = data['drivers'] as List<dynamic>? ?? [];
        return drivers.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<AdminAuthResponse> updateDriverVerification({
    required String driverId,
    required bool isVerified,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/drivers/$driverId/verification'),
            headers: await _headers(),
            body: jsonEncode({'isVerified': isVerified}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminAuthResponse(
        success: response.statusCode == 200 && data['success'] == true,
        message: data['message'] ?? 'Unable to update driver approval',
      );
    } catch (_) {
      return AdminAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: _adminTokenKey);
    await _storage.delete(key: _adminDataKey);
  }
}
