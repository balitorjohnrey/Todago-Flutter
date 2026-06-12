import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ReportIssueResult {
  final bool success;
  final String message;

  const ReportIssueResult({
    required this.success,
    required this.message,
  });
}

class ReportIssueService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/reports';
  static const _storage = FlutterSecureStorage();

  static Future<String?> _tokenForRole(String role) async {
    switch (role) {
      case 'driver':
        return _storage.read(key: 'driver_auth_token');
      case 'operator':
        return _storage.read(key: 'operator_auth_token');
      default:
        return _storage.read(key: 'auth_token');
    }
  }

  static Future<ReportIssueResult> submitReport({
    required String reporterRole,
    required String reportType,
    required String title,
    String? details,
    String? subjectRole,
    String? subjectId,
    String? subjectName,
    String? tripId,
    String priority = 'normal',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await _tokenForRole(reporterRole);
      if (token == null || token.isEmpty) {
        return const ReportIssueResult(
          success: false,
          message: 'Please sign in again before sending a report.',
        );
      }

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'reportType': reportType,
              'title': title,
              if (details != null && details.trim().isNotEmpty)
                'details': details.trim(),
              if (subjectRole != null) 'subjectRole': subjectRole,
              if (subjectId != null && subjectId.isNotEmpty)
                'subjectId': subjectId,
              if (subjectName != null && subjectName.isNotEmpty)
                'subjectName': subjectName,
              if (tripId != null && tripId.isNotEmpty) 'tripId': tripId,
              'priority': priority,
              if (metadata != null) 'metadata': metadata,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ReportIssueResult(
        success: response.statusCode == 201 && data['success'] == true,
        message: data['message']?.toString() ?? 'Unable to submit report.',
      );
    } catch (_) {
      return const ReportIssueResult(
        success: false,
        message: 'Connection failed. Please try again.',
      );
    }
  }
}
