import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'fare_settings_service.dart';

class AdminAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? admin;
  final FareSettings? fareSettings;

  AdminAuthResponse({
    required this.success,
    this.message,
    this.token,
    this.admin,
    this.fareSettings,
  });
}

class AdminAuthService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/admin';
  static const String _fareBaseUrl =
      'https://todago-backend-production.up.railway.app/api/fares';
  static const _storage = FlutterSecureStorage();
  static const _adminTokenKey = 'admin_auth_token';
  static const _adminDataKey = 'admin_data';

  static Future<AdminAuthResponse> login({required String secret}) async {
    try {
      await logout();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'secret': secret.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'];
      if (response.statusCode == 200 &&
          data['success'] == true &&
          token is String &&
          token.isNotEmpty) {
        await _storage.write(key: _adminTokenKey, value: token);
        if (data['admin'] != null) {
          await _storage.write(
            key: _adminDataKey,
            value: jsonEncode(data['admin']),
          );
        }
        return AdminAuthResponse(
          success: true,
          message: data['message'] ?? 'Admin login successful',
          token: token,
          admin: data['admin'],
        );
      }
      await logout();
      return AdminAuthResponse(
        success: false,
        message: data['message'] ?? 'Invalid admin secret',
      );
    } catch (_) {
      await logout();
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

  static Future<List<Map<String, dynamic>>> fetchRoutePerformance({
    int days = 30,
    int limit = 6,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/analytics/routes').replace(
              queryParameters: {
                'days': days.toString(),
                'limit': limit.toString(),
              },
            ),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final routes = data['routes'] as List<dynamic>? ?? [];
        return routes.whereType<Map<String, dynamic>>().toList();
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

  static Future<FareSettings?> fetchFareSettings() async {
    try {
      final response = await http
          .get(Uri.parse('$_fareBaseUrl/settings'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final settings = data['settings'];
      if (response.statusCode == 200 &&
          data['success'] == true &&
          settings is Map<String, dynamic>) {
        return FareSettings.fromJson(settings);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<AdminAuthResponse> updateFareSettings({
    required double fuelPricePerLiter,
    double premiumMultiplier = 1.30,
    List<Map<String, dynamic>>? fareBands,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_fareBaseUrl/settings'),
            headers: await _headers(),
            body: jsonEncode({
              'fuelPricePerLiter': fuelPricePerLiter,
              'premiumMultiplier': premiumMultiplier,
              if (fareBands != null) 'fareBands': fareBands,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final settings = data['settings'];
      return AdminAuthResponse(
        success: response.statusCode == 200 && data['success'] == true,
        message: data['message'] ?? 'Unable to update fare settings',
        fareSettings: settings is Map<String, dynamic>
            ? FareSettings.fromJson(settings)
            : null,
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
