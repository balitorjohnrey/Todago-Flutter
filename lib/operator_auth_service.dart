import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OperatorAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? operator;
  OperatorAuthResponse({required this.success, this.message, this.token, this.operator});
}

class OperatorAuthService {
  // ✅ Replace with your actual Railway URL
  static const String _baseUrl = 'https://YOUR_RAILWAY_URL.up.railway.app/api/operator';
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'operator_auth_token';
  static const _operatorKey = 'operator_data';

  // Register operator — NO password, uses main account password
  static Future<OperatorAuthResponse> register({
    required String associationName,
    required String associationCode,
    required String ltfrbNumber,
    required String region,
    required String contactName,
    required String email,
    required String phone,
    String? serviceArea,
    String? totalTricycles,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'associationName': associationName,
          'associationCode': associationCode,
          'ltfrbNumber': ltfrbNumber,
          'region': region,
          'contactName': contactName,
          'email': email.toLowerCase().trim(),
          'phone': phone.trim(),
          if (serviceArea != null) 'serviceArea': serviceArea,
          if (totalTricycles != null) 'totalTricycles': totalTricycles,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 201) {
        if (data['token'] != null) await _saveSession(data['token'], data['operator']);
        return OperatorAuthResponse(
          success: true,
          message: data['message'] ?? 'Operator account created!',
          token: data['token'], operator: data['operator'],
        );
      }
      return OperatorAuthResponse(success: false, message: data['message'] ?? 'Registration failed');
    } catch (e) {
      return OperatorAuthResponse(success: false,
          message: 'Connection failed. Check your internet.');
    }
  }

  // Login — TODA Association ID + email + main account password
  static Future<OperatorAuthResponse> login({
    required String todaAssociationId,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'todaAssociationId': todaAssociationId.trim(),
          'email': email.toLowerCase().trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (data['token'] != null) await _saveSession(data['token'], data['operator']);
        return OperatorAuthResponse(
          success: true,
          message: data['message'] ?? 'Login successful!',
          token: data['token'], operator: data['operator'],
        );
      }
      return OperatorAuthResponse(success: false, message: data['message'] ?? 'Invalid credentials');
    } catch (e) {
      return OperatorAuthResponse(success: false,
          message: 'Connection failed. Check your internet.');
    }
  }

  static Future<void> _saveSession(String token, Map<String, dynamic>? operator) async {
    await _storage.write(key: _tokenKey, value: token);
    if (operator != null) await _storage.write(key: _operatorKey, value: jsonEncode(operator));
  }

  static Future<String?> getToken() async => await _storage.read(key: _tokenKey);
  static Future<Map<String, dynamic>?> getOperator() async {
    final raw = await _storage.read(key: _operatorKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }
  static Future<void> logout() async => await _storage.deleteAll();
}