import 'dart:convert';

import 'package:http/http.dart' as http;

import 'panabo_config.dart';

class FareSettings {
  final double fuelPricePerLiter;
  final double premiumMultiplier;

  const FareSettings({
    this.fuelPricePerLiter = PanaboFarePolicy.defaultFuelPricePerLiter,
    this.premiumMultiplier = PanaboFarePolicy.defaultPremiumMultiplier,
  });

  PanaboFareBand get band =>
      PanaboFarePolicy.bandForFuelPrice(fuelPricePerLiter);

  double get regularFare => band.regularFare;
  double get discountedFare => band.discountedFare;

  factory FareSettings.fromJson(Map<String, dynamic> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return FareSettings(
      fuelPricePerLiter: readDouble(
        'fuel_price_per_liter',
        PanaboFarePolicy.defaultFuelPricePerLiter,
      ),
      premiumMultiplier: readDouble(
        'premium_multiplier',
        PanaboFarePolicy.defaultPremiumMultiplier,
      ),
    );
  }
}

class FareSettingsService {
  static const String _baseUrl =
      'https://todago-backend-production.up.railway.app/api/fares';

  static Future<FareSettings> fetchSettings() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/settings'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final settings = data['settings'];
        if (data['success'] == true && settings is Map<String, dynamic>) {
          return FareSettings.fromJson(settings);
        }
      }
    } catch (_) {
      // Offline/dev fallback keeps fare calculation usable.
    }
    return const FareSettings();
  }
}
