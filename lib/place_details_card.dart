import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'map_place.dart';
import 'map_service.dart';

class PlaceDetailsCard extends StatelessWidget {
  final MapPlace place;
  final bool loading;
  final bool detailsUnavailable;
  final VoidCallback onDirections;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const PlaceDetailsCard({
    super.key,
    required this.place,
    required this.loading,
    required this.detailsUnavailable,
    required this.onDirections,
    required this.onClose,
    required this.onRetry,
  });

  Widget _attribution(String html) {
    final text = html
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    final href = RegExp('href=["\x27]([^"\x27]+)').firstMatch(html)?.group(1);
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || uri.scheme != 'https') {
      return Text(text, style: const TextStyle(fontSize: 11));
    }
    return TextButton(
      onPressed: () async {
        try {
          await launchUrl(uri);
        } catch (_) {/* Attribution stays visible. */}
      },
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = place.rating;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            )),
            IconButton(
                tooltip: 'Close place',
                onPressed: onClose,
                icon: const Icon(Icons.close)),
          ]),
          if (loading) const LinearProgressIndicator(),
          if (rating != null)
            Semantics(
                label: '$rating out of 5 stars',
                child: Row(children: [
                  Text(rating.toStringAsFixed(1)),
                  const SizedBox(width: 6),
                  for (var star = 1; star <= 5; star++)
                    Icon(
                        rating >= star
                            ? Icons.star
                            : rating >= star - 0.5
                                ? Icons.star_half
                                : Icons.star_border,
                        size: 19,
                        color: AppColors.primary),
                  if (place.ratingCount != null)
                    Flexible(
                        child: Text(' (${place.ratingCount} reviews)',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
          if (place.category != null || place.openNow != null)
            Align(
                alignment: Alignment.centerLeft,
                child: Text([
                  if (place.category != null) place.category!,
                  if (place.openNow != null)
                    place.openNow! ? 'Open now' : 'Closed now',
                ].join(' · '))),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: loading ? null : onDirections,
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Get Directions'),
              )),
          const SizedBox(height: 8),
          Flexible(
              child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (place.address.isNotEmpty) Text(place.address),
              if (detailsUnavailable) ...[
                const Text('Place information is unavailable. '
                    'Check your connection or try again later.'),
                TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry place details')),
              ],
              if (place.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                    height: 165,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: place.photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        final photo = place.photos[index];
                        return SizedBox(
                            width: 230,
                            child: Column(children: [
                              Expanded(
                                  child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  MapService.placePhotoUrl(photo),
                                  width: 230,
                                  fit: BoxFit.cover,
                                  semanticLabel: 'Photo of ${place.name}',
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Text('Photo unavailable')),
                                ),
                              )),
                              for (final credit in photo.attributions)
                                _attribution(credit),
                            ]));
                      },
                    )),
              ],
              if (place.openingHours.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Opening hours'),
                  children: [
                    for (final day in place.openingHours)
                      Align(alignment: Alignment.centerLeft, child: Text(day))
                  ],
                ),
              if (place.phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText('Phone: ${place.phone}'),
                ),
              if (place.website != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText('Website: ${place.website}'),
                ),
              if (place.accessibleEntrance == true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(Icons.accessible, size: 20),
                    SizedBox(width: 6),
                    Expanded(child: Text('Wheelchair-accessible entrance'))
                  ]),
                ),
              for (final credit in place.attributions) _attribution(credit),
            ]),
          )),
        ]),
      ),
    );
  }
}
