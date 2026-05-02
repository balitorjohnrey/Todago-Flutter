import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DriverAuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final Map<String, dynamic>? driver;

  DriverAuthResponse({
    required this.success,
    this.message,
    this.token,
    this.driver,
  });
}

class DriverAuthService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/driver';

  static const _storage = FlutterSecureStorage();

  // Keys — main account token lives under 'auth_token' (set by AuthService)
  static const _mainTokenKey = 'auth_token';    // ← written by AuthService on login/register
  static const _driverTokenKey = 'driver_auth_token';
  static const _driverDataKey = 'driver_data';

  // ── Fetch main account data (auto-fill for driver registration form) ─────────
  // Call this in initState of your DriverRegistrationScreen to pre-fill
  // Full Name, Phone Number, and Email Address from the main account.
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

  // ── Register driver ───────────────────────────────────────────────────────────
  // FIX: Now sends the main account JWT in the Authorization header.
  // The backend reads name/phone/email/password directly from the main account
  // using req.userId — no more phone number mismatches or "No account found".
  //
  // Only vehicle details are needed from the form.
  static Future<DriverAuthResponse> register({
    required String licenseNo,
    required String todaBodyNumber,
    required String plateNo,
    String? vehicleColor,
    String? todaId,
  }) async {
    try {
      // Get main account token — required for registration
      final mainToken = await _storage.read(key: _mainTokenKey);

      if (mainToken == null || mainToken.isEmpty) {
        return DriverAuthResponse(
          success: false,
          message:
              'You must be signed in to your main TodaGo account to register as a driver.',
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
              'licenseNo': licenseNo.trim(),
              'todaBodyNumber': todaBodyNumber.trim(),
              'plateNo': plateNo.trim(),
              if (vehicleColor != null && vehicleColor.isNotEmpty)
                'vehicleColor': vehicleColor,
              if (todaId != null && todaId.isNotEmpty) 'todaId': todaId,
              // name, phone, email are NOT sent — backend reads them from
              // the main account using the token
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        if (data['token'] != null) {
          await _saveSession(data['token'], data['driver']);
        }
        return DriverAuthResponse(
          success: true,
          message: data['message'] ?? 'Driver account created!',
          token: data['token'],
          driver: data['driver'],
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
  // TODA body number + plate number + main account password
  static Future<DriverAuthResponse> login({
    required String todaBodyNumber,
    required String plateNo,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'todaBodyNumber': todaBodyNumber.trim(),
              'plateNo': plateNo.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await _saveSession(data['token'], data['driver']);
        }
        return DriverAuthResponse(
          success: true,
          message: data['message'] ?? 'Login successful!',
          token: data['token'],
          driver: data['driver'],
        );
      }

      return DriverAuthResponse(
        success: false,
        message: data['message'] ?? 'Invalid credentials',
      );
    } catch (e) {
      return DriverAuthResponse(
        success: false,
        message: 'Connection failed. Check your internet.',
      );
    }
  }

  // ── Storage helpers ───────────────────────────────────────────────────────────
  static Future<void> _saveSession(
      String token, Map<String, dynamic>? driver) async {
    await _storage.write(key: _driverTokenKey, value: token);
    if (driver != null) {
      await _storage.write(key: _driverDataKey, value: jsonEncode(driver));
    }
  }

  static Future<String?> getToken() async =>
      await _storage.read(key: _driverTokenKey);

  static Future<Map<String, dynamic>?> getDriver() async {
    final raw = await _storage.read(key: _driverDataKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  // FIX: Clear ALL tokens on logout (main + driver) so no stale sessions remain
  static Future<void> logout() async => await _storage.deleteAll();
}