import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DriverAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? driver;
  DriverAuthResponse({required this.success, this.message, this.token, this.driver});
}

class DriverAuthService {
  static const String _baseUrl = 'https://todago-backend-production.up.railway.app/api/auth';
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'driver_auth_token';
  static const _driverKey = 'driver_data';

  static Future<DriverAuthResponse> register({
    required String driverName,
    required String phone,
    required String licenseNo,
    required String todaBodyNumber,
    required String password,
    String? email,
    String? plateNo,
    String? vehicleColor,
    String? todaId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverName': driverName,
          'phone': phone,
          'licenseNo': licenseNo,
          'todaBodyNumber': todaBodyNumber,
          'password': password,
          if (email != null) 'email': email,
          if (plateNo != null) 'plateNo': plateNo,
          if (vehicleColor != null) 'vehicleColor': vehicleColor,
          if (todaId != null) 'todaId': todaId,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201) {
        if (data['token'] != null) await _saveSession(data['token'], data['driver']);
        return DriverAuthResponse(
          success: true,
          message: data['message'] ?? 'Driver account created!',
          token: data['token'],
          driver: data['driver'],
        );
      }
      return DriverAuthResponse(success: false, message: data['message'] ?? 'Registration failed');
    } catch (e) {
      return DriverAuthResponse(success: false, message: 'Connection failed. Check your internet.');
    }
  }

  static Future<DriverAuthResponse> login({
    required String todaBodyNumber,
    required String plateNo,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'todaBodyNumber': todaBodyNumber.trim(),
          'plateNo': plateNo.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (data['token'] != null) await _saveSession(data['token'], data['driver']);
        return DriverAuthResponse(
          success: true,
          message: 'Login successful! Welcome back 👋',
          token: data['token'],
          driver: data['driver'],
        );
      }
      return DriverAuthResponse(success: false, message: data['message'] ?? 'Invalid credentials');
    } catch (e) {
      return DriverAuthResponse(success: false, message: 'Connection failed. Check your internet.');
    }
  }

  static Future<void> _saveSession(String token, Map<String, dynamic>? driver) async {
    await _storage.write(key: _tokenKey, value: token);
    if (driver != null) await _storage.write(key: _driverKey, value: jsonEncode(driver));
  }

  static Future<String?> getToken() async => await _storage.read(key: _tokenKey);
  static Future<Map<String, dynamic>?> getDriver() async {
    final raw = await _storage.read(key: _driverKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }
  static Future<void> logout() async => await _storage.deleteAll();
}