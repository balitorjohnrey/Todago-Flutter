import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TripService {
  static const String _baseUrl = 'https://todago-backend-production.up.railway.app/api/trips';
  static const _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    // Try all token types
    String? token = await _storage.read(key: 'auth_token');
    token ??= await _storage.read(key: 'driver_auth_token');
    token ??= await _storage.read(key: 'operator_auth_token');
    return token;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Passenger: fetch online drivers ───────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchOnlineDrivers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/drivers/online'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

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
      final response = await http.post(
        Uri.parse('$_baseUrl/request'),
        headers: await _headers(),
        body: jsonEncode({
          'driverId': driverId,
          'pickupLocation': pickupLocation,
          'destination': destination,
          'serviceType': serviceType,
          'fare': fare,
          'paymentMethod': paymentMethod,
        }),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Driver: poll for pending trip request ─────────────────────────────────
  static Future<Map<String, dynamic>?> fetchPendingTrip() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/driver/pending'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

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
      final response = await http.put(
        Uri.parse('$_baseUrl/$tripId/accept'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── Driver: decline trip ──────────────────────────────────────────────────
  static Future<bool> declineTrip(String tripId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/$tripId/decline'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
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
      final response = await http.put(
        Uri.parse('$_baseUrl/$tripId/status'),
        headers: await _headers(),
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Connection failed'};
    }
  }

  // ── Driver: update online/offline status ─────────────────────────────────
  static Future<bool> updateDriverStatus(String status) async {
    try {
      final token = await _storage.read(key: 'driver_auth_token');
      final response = await http.put(
        Uri.parse('${_baseUrl.replaceAll('/api/trips', '/api/driver')}/status'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ── Passenger: get active trip ────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/commuter/active'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
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
      final response = await http.get(
        Uri.parse('$_baseUrl/driver/active'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['trip'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Commuter: trip history ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCommuterHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/commuter/history'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));
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
      final response = await http.get(
        Uri.parse('$_baseUrl/driver/history'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));
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