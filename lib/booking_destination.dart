import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The exact place selected before entering the passenger booking flow.
class BookingDestination {
  final LatLng point;
  final String name;

  const BookingDestination({required this.point, required this.name});
}
