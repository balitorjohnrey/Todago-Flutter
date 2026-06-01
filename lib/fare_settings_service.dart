import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'panabo_config.dart';

class FareSettings {
  final double fuelPricePerLiter;
  final double premiumMultiplier;
  final List<PanaboFareBand> fareBands;

  const FareSettings({
    this.fuelPricePerLiter = PanaboFarePolicy.defaultFuelPricePerLiter,
    this.premiumMultiplier = PanaboFarePolicy.defaultPremiumMultiplier,
    this.fareBands = PanaboFarePolicy.fareBands,
  });

  PanaboFareBand get band => bandForFuelPrice(fuelPricePerLiter);

  double get regularFare => band.regularFare;
  double get discountedFare => band.discountedFare;

  PanaboFareBand bandForFuelPrice(double fuelPrice) {
    return fareBands.firstWhere(
      (band) => band.contains(fuelPrice),
      orElse: () => fareBands.isNotEmpty
          ? fareBands.first
          : PanaboFarePolicy.fareBands.first,
    );
  }

  double fareForDistanceKm(
    double distanceKm, {
    bool discounted = false,
    double premiumMultiplier = 1.0,
    int passengerCount = 1,
  }) {
    final selectedBand = bandForFuelPrice(fuelPricePerLiter);
    final baseFare =
        discounted ? selectedBand.discountedFare : selectedBand.regularFare;
    final extraDistance =
        math.max(0.0, distanceKm - PanaboFarePolicy.firstSegmentKm);
    final extraFare = extraDistance == 0
        ? 0.0
        : PanaboFarePolicy.extraKmFare * extraDistance.ceil();
    final individualFare = (baseFare + extraFare) * premiumMultiplier;
    return individualFare * passengerCount.clamp(1, 6).toInt();
  }

  String fareLabel(
    double distanceKm, {
    bool discounted = false,
    double premiumMultiplier = 1.0,
    int passengerCount = 1,
  }) {
    return PanaboFarePolicy.formatPeso(fareForDistanceKm(
      distanceKm,
      discounted: discounted,
      premiumMultiplier: premiumMultiplier,
      passengerCount: passengerCount,
    ));
  }

  FareSettings copyWith({
    double? fuelPricePerLiter,
    double? premiumMultiplier,
    List<PanaboFareBand>? fareBands,
  }) {
    return FareSettings(
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      premiumMultiplier: premiumMultiplier ?? this.premiumMultiplier,
      fareBands: fareBands ?? this.fareBands,
    );
  }

  Map<String, dynamic> toJson() => {
        'fuelPricePerLiter': fuelPricePerLiter,
        'premiumMultiplier': premiumMultiplier,
        'fareBands': fareBands
            .map((band) => {
                  'minFuelPrice': band.minFuelPrice,
                  'maxFuelPrice': band.maxFuelPrice,
                  'regularFare': band.regularFare,
                  'discountedFare': band.discountedFare,
                })
            .toList(),
      };

  factory FareSettings.fromJson(Map<String, dynamic> json) {
    double readDouble(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    double? readNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final rawBands = json['fare_bands'] ?? json['fareBands'];
    final parsedBands = rawBands is List
        ? rawBands.whereType<Map>().map((raw) {
            final band = Map<String, dynamic>.from(raw);
            double readBandDouble(String snake, String camel) {
              final value = band[snake] ?? band[camel];
              if (value is num) return value.toDouble();
              return double.tryParse(value?.toString() ?? '') ?? 0;
            }

            return PanaboFareBand(
              minFuelPrice: readBandDouble('min_fuel_price', 'minFuelPrice'),
              maxFuelPrice: readNullableDouble(
                band['max_fuel_price'] ?? band['maxFuelPrice'],
              ),
              regularFare: readBandDouble('regular_fare', 'regularFare'),
              discountedFare:
                  readBandDouble('discounted_fare', 'discountedFare'),
            );
          }).toList()
        : <PanaboFareBand>[];

    return FareSettings(
      fuelPricePerLiter: readDouble(
        'fuel_price_per_liter',
        PanaboFarePolicy.defaultFuelPricePerLiter,
      ),
      premiumMultiplier: readDouble(
        'premium_multiplier',
        PanaboFarePolicy.defaultPremiumMultiplier,
      ),
      fareBands: parsedBands.isEmpty ? PanaboFarePolicy.fareBands : parsedBands,
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
