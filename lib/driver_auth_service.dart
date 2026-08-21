import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DriverAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? driver;
  final String? personaVerificationUrl;

  DriverAuthResponse({
    required this.success,
    this.message,
    this.token,
    this.driver,
    this.personaVerificationUrl,
  });
}

class DriverAuthService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/driver';

  static const _storage = FlutterSecureStorage();

  static const _driverTokenKey = 'driver_auth_token';
  static const _driverDataKey = 'driver_data';

  static String? _verificationUrlFrom(Map<String, dynamic> data) {
    final kyc = data['kyc'];
    if (kyc is Map<String, dynamic>) {
      final url = kyc['verificationUrl'];
      if (url is String && url.trim().isNotEmpty) return url;
    }
    final persona = data['persona'];
    if (persona is Map<String, dynamic>) {
      final url = persona['verificationUrl'];
      if (url is String && url.trim().isNotEmpty) return url;
    }
    return null;
  }

  // ── Register driver ───────────────────────────────────────────────────────────
  static Future<DriverAuthResponse> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String driverType,
    required String licenseNo,
    required String todaBodyNumber,
    required String plateNo,
    String? vehicleColor,
    String? todaAssociation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName.trim(),
              'email': email.toLowerCase().trim(),
              'phone': phone.trim(),
              'password': password,
              'driverType': driverType,
              'licenseNo': licenseNo.trim(),
              'todaBodyNumber': todaBodyNumber.trim(),
              'plateNo': plateNo.trim(),
              if (vehicleColor != null && vehicleColor.isNotEmpty)
                'vehicleColor': vehicleColor,
              if (todaAssociation != null && todaAssociation.isNotEmpty)
                'todaAssociation': todaAssociation.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final personaVerificationUrl = _verificationUrlFrom(data);

      if (response.statusCode == 201) {
        if (data['token'] != null) {
          await _saveSession(data['token'], data['driver']);
        }
        return DriverAuthResponse(
          success: true,
          message: data['message'] ?? 'Driver account created!',
          token: data['token'],
          driver: data['driver'],
          personaVerificationUrl: personaVerificationUrl,
        );
      }

      return DriverAuthResponse(
        success: false,
        message: data['message'] ?? 'Registration failed',
      );
    } catch (e) {
      return DriverAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  // ── Login driver ──────────────────────────────────────────────────────────────
  // License number + driver password
  static Future<DriverAuthResponse> login({
    required String driverType,
    required String licenseNo,
    required String password,
    String? todaAssociation,
  }) async {
    try {
      await _clearSession();

      final normalizedLicenseNo = licenseNo.trim();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'driverType': driverType,
              'licenseNo': normalizedLicenseNo,
              'license_no': normalizedLicenseNo,
              if (todaAssociation != null && todaAssociation.isNotEmpty)
                'todaAssociation': todaAssociation.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'];
      final personaVerificationUrl = _verificationUrlFrom(data);

      if (response.statusCode == 200 &&
          data['success'] == true &&
          token is String &&
          token.isNotEmpty) {
        await _saveSession(token, data['driver']);
        return DriverAuthResponse(
          success: true,
          message: data['message'] ?? 'Login successful!',
          token: token,
          driver: data['driver'],
        );
      }

      await _clearSession();
      return DriverAuthResponse(
        success: false,
        message: data['message'] ?? 'Invalid credentials',
        personaVerificationUrl: personaVerificationUrl,
      );
    } catch (e) {
      await _clearSession();
      return DriverAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  // ── Storage helpers ───────────────────────────────────────────────────────────
  static Future<void> _saveSession(
      String token, Map<String, dynamic>? driver) async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'operator_auth_token');
    await _storage.delete(key: 'operator_data');
    await _storage.delete(key: 'admin_auth_token');
    await _storage.delete(key: 'admin_data');
    await _storage.write(key: _driverTokenKey, value: token);
    if (driver != null) {
      await _storage.write(key: _driverDataKey, value: jsonEncode(driver));
    }
  }

  static Future<void> _clearSession() async {
    await _storage.delete(key: _driverTokenKey);
    await _storage.delete(key: _driverDataKey);
  }

  static Future<void> clearSession() async => _clearSession();

  static Future<String?> getToken() async =>
      await _storage.read(key: _driverTokenKey);

  static Future<Map<String, dynamic>?> getDriver() async {
    final raw = await _storage.read(key: _driverDataKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final driver = data['driver'] as Map<String, dynamic>?;
        if (driver != null) {
          await _storage.write(key: _driverDataKey, value: jsonEncode(driver));
          return driver;
        }
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearSession();
        return null;
      }
      return await getDriver();
    } catch (_) {
      return await getDriver();
    }
  }

  static Future<Map<String, dynamic>?> fetchTodayStats() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/stats/today'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['stats'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPeakHours({
    int days = 30,
    int limit = 3,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/peak-hours').replace(
          queryParameters: {
            'days': days.toString(),
            'limit': limit.toString(),
          },
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final hours = data['hours'] as List<dynamic>? ?? [];
        return hours.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> updateProfilePhoto(
      String? profilePhotoUrl) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final response = await http
          .put(
            Uri.parse('$_baseUrl/profile-photo'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'profilePhotoUrl': profilePhotoUrl}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final driver = data['driver'] as Map<String, dynamic>?;
        if (driver != null) {
          await _storage.write(key: _driverDataKey, value: jsonEncode(driver));
          return driver;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearSession();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async => await _storage.deleteAll();
}
