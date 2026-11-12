import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

Future<bool> validateSavedSession({
  required Uri endpoint,
  required Future<String?> Function() readToken,
  required Future<void> Function() clearSession,
  bool allowOffline = false,
}) async {
  final token = await readToken();
  if (token == null || token.isEmpty) return false;

  http.Response? response;
  try {
    response = await http.get(endpoint, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    // Startup can continue with an unexpired token while offline.
  } on http.ClientException {
    // The connection can be unavailable when the app restarts.
  }

  if (await readToken() != token) return false;
  final status = response?.statusCode;
  if (status == 401 || status == 403) {
    await clearSession();
    return false;
  }
  if (response != null && status == 200) {
    try {
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> && data['success'] == true;
    } on FormatException {
      return false;
    }
  }

  final temporarilyUnavailable =
      status == null || status == 408 || status == 429 || status >= 500;
  return allowOffline && temporarilyUnavailable && _isUnexpired(token);
}

bool _isUnexpired(String token) {
  final parts = token.split('.');
  if (parts.length != 3 || parts.last.isEmpty) return false;
  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(
      base64Url.normalize(parts[1]),
    )));
    final expiresAt = payload is Map<String, dynamic> ? payload['exp'] : null;
    return expiresAt is int &&
        expiresAt * Duration.millisecondsPerSecond >
            DateTime.now().millisecondsSinceEpoch;
  } on FormatException {
    return false;
  }
}
