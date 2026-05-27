import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PanaboConfig {
  static const LatLng cityCenter = LatLng(7.29937, 125.68191);
  static const LatLng cityMuseum = cityCenter;
  static const String cityName = 'Panabo City';
  static const String fareAnchorName = 'Museo Panabo';
  static const double searchRadiusMeters = 25000;
}

class PanaboFareBand {
  final double minFuelPrice;
  final double? maxFuelPrice;
  final double regularFare;
  final double discountedFare;

  const PanaboFareBand({
    required this.minFuelPrice,
    required this.maxFuelPrice,
    required this.regularFare,
    required this.discountedFare,
  });

  bool contains(double fuelPrice) {
    return fuelPrice >= minFuelPrice &&
        (maxFuelPrice == null || fuelPrice <= maxFuelPrice!);
  }
}

class PanaboFarePolicy {
  static const double firstSegmentKm = 3.0;
  static const double regularMinimumFare = 15.0;
  static const double defaultFuelPricePerLiter = 60.0;
  static const double extraKmFare = 5.0;
  static const double tricycleAverageSpeedKmh = 19.94;

  static const List<PanaboFareBand> fareBands = [
    PanaboFareBand(
      minFuelPrice: 20,
      maxFuelPrice: 29.99,
      regularFare: 10,
      discountedFare: 8,
    ),
    PanaboFareBand(
      minFuelPrice: 30,
      maxFuelPrice: 39.99,
      regularFare: 12,
      discountedFare: 10,
    ),
    PanaboFareBand(
      minFuelPrice: 40,
      maxFuelPrice: 49.99,
      regularFare: 13,
      discountedFare: 11,
    ),
    PanaboFareBand(
      minFuelPrice: 50,
      maxFuelPrice: 59.99,
      regularFare: 14,
      discountedFare: 12,
    ),
    PanaboFareBand(
      minFuelPrice: 60,
      maxFuelPrice: 69.99,
      regularFare: 15,
      discountedFare: 13,
    ),
    PanaboFareBand(
      minFuelPrice: 70,
      maxFuelPrice: 79.99,
      regularFare: 16,
      discountedFare: 14,
    ),
    PanaboFareBand(
      minFuelPrice: 80,
      maxFuelPrice: 89.99,
      regularFare: 17,
      discountedFare: 15,
    ),
    PanaboFareBand(
      minFuelPrice: 90,
      maxFuelPrice: 99.99,
      regularFare: 18,
      discountedFare: 16,
    ),
    PanaboFareBand(
      minFuelPrice: 100,
      maxFuelPrice: null,
      regularFare: 20,
      discountedFare: 18,
    ),
  ];

  static PanaboFareBand bandForFuelPrice([
    double fuelPricePerLiter = defaultFuelPricePerLiter,
  ]) {
    return fareBands.firstWhere(
      (band) => band.contains(fuelPricePerLiter),
      orElse: () => fareBands.first,
    );
  }

  static double fareForDistanceKm(
    double distanceKm, {
    bool discounted = false,
    double fuelPricePerLiter = defaultFuelPricePerLiter,
  }) {
    final band = bandForFuelPrice(fuelPricePerLiter);
    final postedFare = discounted ? band.discountedFare : band.regularFare;
    final baseFare = discounted
        ? postedFare
        : math.max(regularMinimumFare, postedFare).toDouble();
    final extraDistance = math.max(0.0, distanceKm - firstSegmentKm);
    final extraFare =
        extraDistance == 0 ? 0.0 : extraKmFare * extraDistance.ceil();
    return baseFare + extraFare;
  }

  static String fareLabel(
    double distanceKm, {
    bool discounted = false,
    double fuelPricePerLiter = defaultFuelPricePerLiter,
  }) {
    return formatPeso(fareForDistanceKm(
      distanceKm,
      discounted: discounted,
      fuelPricePerLiter: fuelPricePerLiter,
    ));
  }

  static String formatPeso(double amount) => 'PHP ${amount.toStringAsFixed(0)}';

  static int etaMinutesForDistanceKm(
    double distanceKm, {
    double trafficMultiplier = 1.0,
  }) {
    if (distanceKm <= 0) return 1;
    final minutes =
        (distanceKm / tricycleAverageSpeedKmh) * 60 * trafficMultiplier;
    return math.max(1, minutes.ceil());
  }

  static double trafficMultiplier({
    required double normalDurationSeconds,
    required double trafficDurationSeconds,
  }) {
    if (normalDurationSeconds <= 0 || trafficDurationSeconds <= 0) return 1.0;
    return (trafficDurationSeconds / normalDurationSeconds)
        .clamp(0.85, 2.5)
        .toDouble();
  }
}
