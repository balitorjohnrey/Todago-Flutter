import 'dart:convert';
import 'package:http/http.dart' as http;

class IdentityVerificationService {
  static Future<Map<String, dynamic>> checkStatus(String? token) async {
    if (token == null || token.isEmpty) {
      throw StateError(
          'Verification status is unavailable. Please sign in again.');
    }
    final response = await http.get(
      Uri.parse(
          'https://todago-backend-production.up.railway.app/api/kyc/session/status'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode == 401 || response.statusCode == 404) {
      throw StateError(
          'This verification session has expired. Please sign in again.');
    }
    if (response.statusCode != 200) {
      throw StateError('Unable to check verification. Please try again.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true || data['identity'] is! Map<String, dynamic>) {
      throw StateError('Unable to check verification. Please try again.');
    }
    return data['identity'] as Map<String, dynamic>;
  }
}
