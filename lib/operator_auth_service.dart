import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OperatorAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? operator;

  OperatorAuthResponse({
    required this.success,
    this.message,
    this.token,
    this.operator,
  });
}

class OperatorAuthService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/operator';

  static const _storage = FlutterSecureStorage();

  // Keys — main account token lives under 'auth_token' (set by AuthService)
  static const _mainTokenKey = 'auth_token';      // ← written by AuthService
  static const _operatorTokenKey = 'operator_auth_token';
  static const _operatorDataKey = 'operator_data';

  // ── Fetch main account data (auto-fill for operator registration form) ───────
  // Call this in initState of your OperatorRegistrationScreen to pre-fill
  // Contact Name, Email, and Phone from the main account.
  //
  // Returns null if the user is not signed in to their main account.
  static Future<Map<String, dynamic>?> fetchMainAccountData() async {
    try {
      final token = await _storage.read(key: _mainTokenKey);
      if (token == null || token.isEmpty) return null;

      final response = await http
          .get(
            Uri.parse(
                'https://todago-backend-production.up.railway.app/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Returns: { id, full_name, email, phone, role, ... }
        return data['user'] as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Register operator ─────────────────────────────────────────────────────────
  // FIX: Now sends the main account JWT in the Authorization header.
  // The backend reads name/phone/email/password directly from the main account
  // using req.userId — no more "No account found" errors.
  //
  // Only association details are needed from the form.
  static Future<OperatorAuthResponse> register({
    required String associationName,
    required String associationCode,
    required String ltfrbNumber,
    required String region,
    String? serviceArea,
    String? totalTricycles,
  }) async {
    try {
      // Get main account token — required for registration
      final mainToken = await _storage.read(key: _mainTokenKey);

      if (mainToken == null || mainToken.isEmpty) {
        return OperatorAuthResponse(
          success: false,
          message:
              'You must be signed in to your main TodaGo account to register as an operator.',
        );
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $mainToken', // ← FIX: send main token
            },
            body: jsonEncode({
              'associationName': associationName.trim(),
              'associationCode': associationCode.trim(),
              'ltfrbNumber': ltfrbNumber.trim(),
              'region': region.trim(),
              if (serviceArea != null && serviceArea.isNotEmpty)
                'serviceArea': serviceArea,
              if (totalTricycles != null && totalTricycles.isNotEmpty)
                'totalTricycles': totalTricycles,
              // contactName, email, phone are NOT sent — backend reads them
              // from the main account using the token
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        if (data['token'] != null) {
          await _saveSession(data['token'], data['operator']);
        }
        return OperatorAuthResponse(
          success: true,
          message: data['message'] ?? 'Operator account created!',
          token: data['token'],
          operator: data['operator'],
        );
      }

      return OperatorAuthResponse(
        success: false,
        message: data['message'] ?? 'Registration failed',
      );
    } catch (e) {
      return OperatorAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  // ── Login operator ────────────────────────────────────────────────────────────
  // TODA Association ID (code) + email + main account password
  static Future<OperatorAuthResponse> login({
    required String todaAssociationId,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'todaAssociationId': todaAssociationId.trim(),
              'email': email.toLowerCase().trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await _saveSession(data['token'], data['operator']);
        }
        return OperatorAuthResponse(
          success: true,
          message: data['message'] ?? 'Login successful!',
          token: data['token'],
          operator: data['operator'],
        );
      }

      return OperatorAuthResponse(
        success: false,
        message: data['message'] ?? 'Invalid credentials',
      );
    } catch (e) {
      return OperatorAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  // ── Storage helpers ───────────────────────────────────────────────────────────
  static Future<void> _saveSession(
      String token, Map<String, dynamic>? operator) async {
    await _storage.write(key: _operatorTokenKey, value: token);
    if (operator != null) {
      await _storage.write(key: _operatorDataKey, value: jsonEncode(operator));
    }
  }

  static Future<String?> getToken() async =>
      await _storage.read(key: _operatorTokenKey);

  static Future<Map<String, dynamic>?> getOperator() async {
    final raw = await _storage.read(key: _operatorDataKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  // FIX: Clear ALL tokens on logout (main + operator) so no stale sessions remain
  static Future<void> logout() async => await _storage.deleteAll();
}