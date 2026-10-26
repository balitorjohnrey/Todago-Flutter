import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_service.dart';

/// Shared presentation for every map that displays directions.
class RouteDisplay {
  static const recommendedColor = Color(0xFF1A73E8);
  static const alternativeColor = Color(0xFF8BC9F4);

  static Set<Polyline> polylines(
    List<MapRoute> routes, {
    ValueChanged<int>? onSelected,
    int selectedIndex = 0,
  }) {
    return {
      for (var i = routes.length - 1; i >= 0; i--)
        Polyline(
          polylineId: PolylineId('route-$i'),
          points: routes[i].points,
          color: i == 0 ? recommendedColor : alternativeColor,
          width: i == 0 || i == selectedIndex ? 6 : 4,
          zIndex: i == 0 ? 2 : 1,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          consumeTapEvents: onSelected != null,
          onTap: onSelected == null ? null : () => onSelected(i),
        ),
    };
  }
}

class RouteChoices extends StatelessWidget {
  final List<MapRoute> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const RouteChoices({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(
          '${routes.length} road route${routes.length == 1 ? '' : 's'} available',
          style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < routes.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ChoiceChip(
              selected: selectedIndex == i,
              onSelected: (_) => onSelected(i),
              avatar: CircleAvatar(
                radius: 5,
                backgroundColor: i == 0
                    ? RouteDisplay.recommendedColor
                    : RouteDisplay.alternativeColor,
              ),
              label: Text(
                '${i == 0 ? 'Suggested' : 'Route ${i + 1}'} · '
                '${routes[i].etaMinutes} min · '
                '${routes[i].distanceKm.toStringAsFixed(1)} km',
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}
