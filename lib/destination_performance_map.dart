import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_theme.dart';
import 'panabo_config.dart';

class DestinationPerformanceCard extends StatefulWidget {
  final Future<List<Map<String, dynamic>>?> Function() load;
  final String scope;

  const DestinationPerformanceCard(
      {super.key, required this.load, required this.scope});

  @override
  State<DestinationPerformanceCard> createState() =>
      _DestinationPerformanceCardState();
}

class _DestinationPerformanceCardState
    extends State<DestinationPerformanceCard> {
  List<Map<String, dynamic>>? _data;
  Timer? _timer;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_loading) _reload();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    List<Map<String, dynamic>>? data;
    try {
      data = await widget.load();
    } catch (_) {/* Preserve the last result. */}
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = data == null;
      if (data != null) _data = data;
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EDF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.map_outlined, color: Colors.blue, size: 24),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Route Performance Analysis',
                    style: TextStyle(
                        color: AppColors.backgroundDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: _loading ? null : _reload,
                tooltip: 'Refresh destination map',
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.backgroundDark),
          ]),
          Text('${widget.scope} · Successful rides · Last 30 days',
              style: const TextStyle(color: Color(0xFF526879), fontSize: 11)),
          const SizedBox(height: 12),
          if (_loading && _data == null)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator())),
          if (_failed)
            Text(
                _data == null
                    ? 'Unable to load destinations. Tap refresh to retry.'
                    : 'Unable to refresh. Showing the last available data.',
                style: const TextStyle(color: Color(0xFF526879), fontSize: 12)),
          if (_data != null) DestinationPerformanceMap(data: _data!),
          const SizedBox(height: 8),
          const Text('Updates every 15 seconds after successful rides.',
              style: TextStyle(color: Color(0xFF526879), fontSize: 11)),
        ]),
      );
}

enum _Demand {
  low('Low', Color(0xFF2563EB), BitmapDescriptor.hueAzure),
  moderate('Moderate', Color(0xFFF59E0B), BitmapDescriptor.hueOrange),
  high('High', Color(0xFFDC2626), BitmapDescriptor.hueRed);

  const _Demand(this.label, this.color, this.hue);
  final String label;
  final Color color;
  final double hue;
}

class DestinationPerformanceMap extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const DestinationPerformanceMap({super.key, required this.data});

  @override
  State<DestinationPerformanceMap> createState() =>
      _DestinationPerformanceMapState();
}

class _DestinationPerformanceMapState extends State<DestinationPerformanceMap> {
  GoogleMapController? _controller;
  String? _selectedId;
  bool _fitted = false;

  static double? _number(Object? value) {
    final number = double.tryParse('$value');
    return number != null && number.isFinite ? number : null;
  }

  int _count(Map<String, dynamic> row) =>
      (_number(row['completed_trips']) ?? 0).toInt();
  LatLng? _position(Map<String, dynamic> row) {
    final lat = _number(row['destination_lat']),
        lng = _number(row['destination_lng']);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  _Demand _demand(Map<String, dynamic> row, int max) {
    final ratio = max == 0 ? 0 : _count(row) / max;
    return ratio >= 2 / 3
        ? _Demand.high
        : ratio >= 1 / 3
            ? _Demand.moderate
            : _Demand.low;
  }

  String _id(Map<String, dynamic> row) => '${row['destination_id']}';

  Future<void> _fit() async {
    final points = widget.data.map(_position).whereType<LatLng>().toList();
    if (_controller == null || points.isEmpty) return;
    _fitted = true;
    if (points.length == 1) {
      await _controller!
          .animateCamera(CameraUpdate.newLatLngZoom(points.first, 14));
    } else {
      var south = points.first.latitude, north = south;
      var west = points.first.longitude, east = west;
      for (final p in points) {
        south = math.min(south, p.latitude);
        north = math.max(north, p.latitude);
        west = math.min(west, p.longitude);
        east = math.max(east, p.longitude);
      }
      await _controller!.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
              southwest: LatLng(south - .002, west - .002),
              northeast: LatLng(north + .002, east + .002)),
          40));
    }
  }

  void _select(Map<String, dynamic> row) {
    setState(() => _selectedId = _id(row));
    final position = _position(row);
    if (position != null) {
      _controller?.animateCamera(CameraUpdate.newLatLng(position));
    }
  }

  @override
  void didUpdateWidget(covariant DestinationPerformanceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_fitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.data.where((row) => _count(row) > 0).toList()
      ..sort((a, b) => _count(b).compareTo(_count(a)));
    final located = rows.where((row) => _position(row) != null).toList();
    final max = rows.fold(0, (max, row) => math.max(max, _count(row)));
    final total = rows.fold(0, (sum, row) => sum + _count(row));
    final missing = rows
        .where((row) => _position(row) == null)
        .fold(0, (sum, row) => sum + _count(row));
    final selected = rows.isEmpty
        ? null
        : rows.firstWhere((row) => _id(row) == _selectedId,
            orElse: () => located.isNotEmpty ? located.first : rows.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          '$total completed ride${total == 1 ? '' : 's'} · '
          '${rows.length} destination area${rows.length == 1 ? '' : 's'}',
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.backgroundDark,
              fontSize: 12)),
      const SizedBox(height: 10),
      ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
              height: 300,
              child: Stack(children: [
                GoogleMap(
                  key: const ValueKey('destination-performance-map'),
                  initialCameraPosition: CameraPosition(
                      target: located.isEmpty
                          ? PanaboConfig.cityCenter
                          : _position(located.first)!,
                      zoom: 13),
                  onMapCreated: (controller) {
                    _controller = controller;
                    _fit();
                  },
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  markers: {
                    for (final row in located)
                      Marker(
                          markerId: MarkerId(_id(row)),
                          position: _position(row)!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              _demand(row, max).hue),
                          infoWindow: InfoWindow(
                              title: '${row['destination']}',
                              snippet:
                                  '${_count(row)} completed rides · ${_demand(row, max).label} demand'),
                          onTap: () => _select(row))
                  },
                  circles: {
                    for (final row in located)
                      Circle(
                          circleId: CircleId(_id(row)),
                          center: _position(row)!,
                          radius: 75 + 125 * _count(row) / math.max(1, max),
                          fillColor:
                              _demand(row, max).color.withValues(alpha: .22),
                          strokeColor: _demand(row, max).color,
                          strokeWidth: 2,
                          consumeTapEvents: true,
                          onTap: () => _select(row))
                  },
                ),
                if (located.isEmpty)
                  Center(
                      child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              rows.isEmpty
                                  ? 'No successful rides yet.\nCompleted rides will appear here.'
                                  : 'No GPS coordinates for these destinations yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.backgroundDark,
                                  fontSize: 12)))),
                if (located.isNotEmpty)
                  Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: IconButton(
                              onPressed: _fit,
                              tooltip: 'Show all destinations',
                              color: AppColors.backgroundDark,
                              icon: const Icon(Icons.fit_screen)))),
              ]))),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 6, children: [
        for (final demand in _Demand.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, color: demand.color, size: 10),
            const SizedBox(width: 5),
            Text(demand.label,
                style: const TextStyle(
                    color: AppColors.backgroundDark, fontSize: 11))
          ])
      ]),
      const SizedBox(height: 4),
      const Text(
          'Popularity relative to the busiest destination: low <⅓, moderate ⅓–⅔, high ≥⅔. Tap a destination for details.',
          style: TextStyle(color: Color(0xFF526879), fontSize: 11)),
      if (missing > 0)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                '$missing completed rides have no valid destination GPS. Available in the destination list.',
                style:
                    const TextStyle(color: Color(0xFF526879), fontSize: 11))),
      if (selected != null) ...[
        const SizedBox(height: 12),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFF2F6FA),
                borderRadius: BorderRadius.circular(10)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${selected['destination']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.backgroundDark,
                      fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                  '${_count(selected)} completed rides · ${selected['ride_share'] ?? 0}% of successful rides',
                  style: const TextStyle(
                      color: AppColors.backgroundDark, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                  'Revenue: PHP ${(_number(selected['gross_revenue']) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.backgroundDark, fontSize: 12)),
              Text(
                  'Average trip: ${_number(selected['avg_trip_minutes'])?.toStringAsFixed(1) ?? 'Unavailable'}${selected['avg_trip_minutes'] == null ? '' : ' min'}',
                  style: const TextStyle(
                      color: AppColors.backgroundDark, fontSize: 12)),
              Text(
                  'Last completed: ${_dateLabel(context, selected['last_completed_at'])}',
                  style: const TextStyle(
                      color: AppColors.backgroundDark, fontSize: 12)),
            ])),
        Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('View all destinations',
                    style: TextStyle(
                        color: AppColors.backgroundDark, fontSize: 12)),
                children: [
                  for (final row in rows)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        selected: _id(row) == _id(selected),
                        leading: Icon(
                            _position(row) == null
                                ? Icons.location_off_outlined
                                : Icons.place,
                            color: _demand(row, max).color),
                        title: Text('${row['destination']}',
                            style: const TextStyle(
                                color: AppColors.backgroundDark, fontSize: 12)),
                        subtitle: Text(
                            '${_count(row)} completed rides${_position(row) == null ? ' · GPS unavailable' : ''}',
                            style: const TextStyle(
                                color: Color(0xFF526879), fontSize: 11)),
                        onTap: () => _select(row))
                ])),
      ],
    ]);
  }

  String _dateLabel(BuildContext context, Object? raw) {
    final date = DateTime.tryParse('$raw');
    if (date == null) return 'Unavailable';
    final local = date.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatMediumDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}
