import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TripService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/trips';
  static const _storage = FlutterSecureStorage();

  // ── FIX: Separate token getters per role ──────────────────────────────────
  // Using a single _getToken() that tries auth_token first caused driver
  // endpoints to receive the passenger token (role='passenger') → 403.

  /// Passenger token — for ride requests, finding drivers, commuter history
  static Future<String?> _getPassengerToken() async =>
      await _storage.read(key: 'auth_token');

  /// Driver token — for pending trips, accept/decline, status updates
  static Future<String?> _getDriverToken() async =>
      await _storage.read(key: 'driver_auth_token');

  /// Operator token
  static Future<String?> _getOperatorToken() async =>
      await _storage.read(key: 'operator_auth_token');

  /// Smart token: tries passenger first, then driver, then operator.
  /// Only used for endpoints that work for any authenticated user.
  static Future<String?> _getAnyToken() async {
    return await _getPassengerToken() ??
        await _getDriverToken() ??
        await _getOperatorToken();
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Passenger: fetch online drivers ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchOnlineDrivers() async {
    try {
      final token = await _getPassengerToken();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/drivers/online'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> drivers = data['drivers'] ?? [];
        return drivers.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Passenger: request a ride ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> requestRide({
    required String driverId,
    required String pickupLocation,
    required String destination,
    required String serviceType,
    required double fare,
    required String paymentMethod,
  }) async {
    try {
      // ── FIX: always use passenger token for ride requests ─────────────────
      final token = await _getPassengerToken();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/request'),
            headers: _headers(token),
            body: jsonEncode({
              'driverId': driverId,
              'pickupLocation': pickupLocation,
              'destination': destination,
              'serviceType': serviceType,
              'fare': fare,
              'paymentMethod': paymentMethod,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Driver: poll for pending trip request ─────────────────────────────────
  static Future<Map<String, dynamic>?> fetchPendingTrip() async {
    try {
      // ── FIX: always use driver token for driver endpoints ─────────────────
      final token = await _getDriverToken();
      final response = await http
          .get(
            Uri.parse('$_baseUrl/driver/pending'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['hasPendingTrip'] == true) return data['trip'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Driver: accept trip ───────────────────────────────────────────────────
  static Future<bool> acceptTrip(String tripId) async {
    try {
      final token = await _getDriverToken(); // ← driver token
      final response = await http
          .put(
            Uri.parse('$_baseUrl/$tripId/accept'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── Driver: decline trip ──────────────────────────────────────────────────
  static Future<bool> declineTrip(String tripId) async {
    try {
      final token = await _getDriverToken(); // ← driver token
      final response = await http
          .put(
            Uri.parse('$_baseUrl/$tripId/decline'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── Driver: update trip status ────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateTripStatus(
      String tripId, String status) async {
    try {
      final token = await _getDriverToken(); // ← driver token
      final response = await http
          .put(
            Uri.parse('$_baseUrl/$tripId/status'),
            headers: _headers(token),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Driver: update online/offline status ─────────────────────────────────
  static Future<bool> updateDriverStatus(String status) async {
    try {
      final token = await _getDriverToken(); // ← driver token
      final response = await http
          .put(
            Uri.parse(
                'https://todago-backend-production.up.railway.app/api/driver/status'),
            headers: _headers(token),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── Passenger: get active trip ────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      final token = await _getPassengerToken(); // ← passenger token
      final response = await http
          .get(
            Uri.parse('$_baseUrl/commuter/active'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['trip'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Driver: get active trip ───────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getDriverActiveTrip() async {
    try {
      final token = await _getDriverToken(); // ← driver token
      final response = await http
          .get(
            Uri.parse('$_baseUrl/driver/active'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['trip'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Passenger: trip history ───────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCommuterHistory() async {
    try {
      final token = await _getPassengerToken(); // ← passenger token
      final response = await http
          .get(
            Uri.parse('$_baseUrl/commuter/history'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List trips = data['trips'] ?? [];
        return trips.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Driver: trip history ──────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDriverHistory() async {
    try {
      final token = await _getDriverToken(); // ← driver token
      final response = await http
          .get(
            Uri.parse('$_baseUrl/driver/history'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List trips = data['trips'] ?? [];
        return trips.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}