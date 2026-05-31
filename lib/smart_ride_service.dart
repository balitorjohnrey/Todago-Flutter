import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class RideIntent {
  final String intent;
  final double confidence;
  final String pickupMode;
  final String pickupQuery;
  final String destinationQuery;
  final String serviceType;
  final String scheduledForText;
  final bool needsConfirmation;
  final String reply;

  const RideIntent({
    required this.intent,
    required this.confidence,
    required this.pickupMode,
    required this.pickupQuery,
    required this.destinationQuery,
    required this.serviceType,
    required this.scheduledForText,
    required this.needsConfirmation,
    required this.reply,
  });

  factory RideIntent.fromJson(Map<String, dynamic> json) {
    return RideIntent(
      intent: json['intent']?.toString() ?? 'other',
      confidence: double.tryParse(json['confidence']?.toString() ?? '') ?? 0.0,
      pickupMode: json['pickupMode']?.toString() ?? 'unknown',
      pickupQuery: json['pickupQuery']?.toString() ?? '',
      destinationQuery: json['destinationQuery']?.toString() ?? '',
      serviceType: json['serviceType']?.toString() ?? 'unknown',
      scheduledForText: json['scheduledForText']?.toString() ?? '',
      needsConfirmation: json['needsConfirmation'] != false,
      reply: json['reply']?.toString() ?? '',
    );
  }

  bool get isRideIntent => intent == 'book_ride' || intent == 'schedule_ride';

  bool get canContinueBooking =>
      isRideIntent && destinationQuery.trim().isNotEmpty;

  String? get selectedServiceType {
    final value = serviceType.toLowerCase();
    if (value == 'solo' || value == 'shared' || value == 'express') {
      return value;
    }
    return null;
  }
}

class SmartRideService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/ai';

  static Future<RideIntent?> parseRideIntent(String message) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ride-intent'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['intent'] is! Map) return null;
      return RideIntent.fromJson(
        Map<String, dynamic>.from(data['intent'] as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
