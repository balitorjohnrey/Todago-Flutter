import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacePhoto {
  final String reference;
  final List<String> attributions;

  const PlacePhoto({required this.reference, this.attributions = const []});
}

/// The identity and coordinates of one selected place travel together.
class MapPlace {
  final String? placeId;
  final LatLng point;
  final String name;
  final String address;
  final double? rating;
  final int? ratingCount;
  final String? category;
  final bool? openNow;
  final List<String> openingHours;
  final String? phone;
  final String? website;
  final bool? accessibleEntrance;
  final List<PlacePhoto> photos;
  final List<String> attributions;

  const MapPlace({
    this.placeId,
    required this.point,
    required this.name,
    this.address = '',
    this.rating,
    this.ratingCount,
    this.category,
    this.openNow,
    this.openingHours = const [],
    this.phone,
    this.website,
    this.accessibleEntrance,
    this.photos = const [],
    this.attributions = const [],
  });

  factory MapPlace.fromGoogle(Map<String, dynamic> data) {
    final location = data['geometry']['location'] as Map;
    final types = (data['types'] as List? ?? []).cast<String>();
    final category = types
        .where((type) => !{
              'point_of_interest',
              'establishment',
              'premise',
              'political',
            }.contains(type))
        .firstOrNull;
    return MapPlace(
      placeId: data['place_id'] as String?,
      point: LatLng((location['lat'] as num).toDouble(),
          (location['lng'] as num).toDouble()),
      name: data['name'] as String? ?? 'Selected place',
      address: data['formatted_address'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble(),
      ratingCount: (data['user_ratings_total'] as num?)?.toInt(),
      category: category?.replaceAll('_', ' '),
      openNow: data['opening_hours']?['open_now'] as bool?,
      openingHours: (data['opening_hours']?['weekday_text'] as List? ?? [])
          .cast<String>(),
      phone: data['formatted_phone_number'] as String?,
      website: data['website'] as String?,
      accessibleEntrance: data['wheelchair_accessible_entrance'] as bool?,
      photos: [
        for (final photo in data['photos'] as List? ?? [])
          if (photo['photo_reference'] is String)
            PlacePhoto(
              reference: photo['photo_reference'] as String,
              attributions:
                  (photo['html_attributions'] as List? ?? []).cast<String>(),
            ),
      ],
      attributions: (data['html_attributions'] as List? ?? []).cast<String>(),
    );
  }
}
