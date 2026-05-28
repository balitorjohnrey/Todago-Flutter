import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? user;

  AuthResponse({required this.success, this.message, this.token, this.user});
}

class AuthService {
  // ✅ Your deployed Railway URL — replace after deploying the backend
  // Example: 'https://todago-backend-production.up.railway.app/api/auth'
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/auth';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _roleKey = 'user_role';

  // ─── Register ───────────────────────────────────────────────────────────────
  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName,
              'email': email.toLowerCase().trim(),
              'phone': phone.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'];

      if (response.statusCode == 201 &&
          data['success'] == true &&
          token is String &&
          token.isNotEmpty) {
        await _saveSession(token, data['user']);
        return AuthResponse(
          success: true,
          message: 'Account created successfully! Welcome to TodaGo 🎉',
          token: token,
          user: data['user'],
        );
      }
      return AuthResponse(
          success: false, message: data['message'] ?? 'Registration failed');
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Connection failed. Please check your internet and try again.',
      );
    }
  }

  // ─── Login ──────────────────────────────────────────────────────────────────
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      await _clearSession();

      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'];

      if (response.statusCode == 200 &&
          data['success'] == true &&
          token is String &&
          token.isNotEmpty) {
        await _saveSession(token, data['user']);
        return AuthResponse(
          success: true,
          message: 'Login successful! Welcome back 👋',
          token: token,
          user: data['user'],
        );
      }
      await _clearSession();
      return AuthResponse(
          success: false, message: data['message'] ?? 'Invalid credentials');
    } catch (e) {
      await _clearSession();
      return AuthResponse(
        success: false,
        message: 'Connection failed. Please check your internet and try again.',
      );
    }
  }

  // ─── Save Role to server ────────────────────────────────────────────────────
  static Future<void> saveRoleToServer(String role) async {
    try {
      final token = await getToken();
      if (token == null) return;
      await http
          .put(
            Uri.parse('$_baseUrl/role'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'role': role}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ─── Storage Helpers ────────────────────────────────────────────────────────
  static Future<void> _saveSession(
      String token, Map<String, dynamic>? user) async {
    await _storage.write(key: _tokenKey, value: token);
    if (user != null) {
      await _storage.write(key: _userKey, value: jsonEncode(user));
    }
  }

  static Future<void> _clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: 'driver_auth_token');
    await _storage.delete(key: 'driver_data');
    await _storage.delete(key: 'operator_auth_token');
    await _storage.delete(key: 'operator_data');
    await _storage.delete(key: 'admin_auth_token');
    await _storage.delete(key: 'admin_data');
  }

  static Future<void> saveRole(String role) async {
    await _storage.write(key: _roleKey, value: role);
    await saveRoleToServer(role); // also sync to server
  }

  static Future<String?> getRole() async => await _storage.read(key: _roleKey);
  static Future<String?> getToken() async =>
      await _storage.read(key: _tokenKey);

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: _userKey);
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
        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          await _storage.write(key: _userKey, value: jsonEncode(user));
          return user;
        }
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _clearSession();
        return null;
      }
      return await getUser();
    } catch (_) {
      return await getUser();
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
