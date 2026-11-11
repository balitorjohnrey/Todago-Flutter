import 'dart:convert';
import 'package:http/http.dart' as http;
import 'admin_auth_service.dart';
import 'operator_auth_service.dart';

class MonitoringService {
  static const _api = 'https://todago-backend-production.up.railway.app/api';

  static Future<Map<String, dynamic>?> _get(String path,
      {bool operator = false, Map<String, String> query = const {}}) async {
    try {
      final token = operator
          ? await OperatorAuthService.getToken()
          : await AdminAuthService.getToken();
      final response = await http.get(
        Uri.parse('$_api/$path').replace(queryParameters: query),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body);
      return response.statusCode == 200 &&
              data is Map<String, dynamic> &&
              data['success'] == true
          ? data
          : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchDrivers(
      {bool operator = false}) async {
    final data = await _get(
        operator ? 'operator/analytics/drivers' : 'admin/monitoring/drivers',
        operator: operator);
    return data == null ? null : records(data['drivers']);
  }

  static Future<List<Map<String, dynamic>>?> fetchPendingReports() async {
    final data = await _get('admin/reports');
    return data == null ? null : records(data['reports']);
  }

  static Future<Map<String, dynamic>?> fetchCharges(
          {String? label, int offset = 0, int days = 30}) =>
      _get('admin/monitoring/charges', query: {
        'offset': '$offset',
        'days': '$days',
        if (label != null) 'label': label,
      });

  static Future<Map<String, dynamic>?> fetchGps(
          {String? driverId,
          String? tripId,
          int days = 1,
          Map<String, dynamic>? cursor}) =>
      _get('admin/monitoring/gps', query: {
        'days': '$days',
        if (driverId != null) 'driverId': driverId,
        if (tripId != null) 'tripId': tripId,
        if (cursor != null)
          ...cursor.map((key, value) => MapEntry(key, value.toString())),
      });

  static List<Map<String, dynamic>> records(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : [];
}
