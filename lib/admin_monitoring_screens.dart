import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
import 'monitoring_service.dart';
import 'panabo_config.dart';

String _money(dynamic value) =>
    PanaboFarePolicy.formatPeso(double.tryParse('$value') ?? 0);
String _time(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Time unavailable';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
}

class _MonitoringPage extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onRefresh;
  const _MonitoringPage(
      {required this.title, required this.body, this.onRefresh});

  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          textTheme: Theme.of(context).textTheme.apply(
              bodyColor: AppColors.backgroundDark,
              displayColor: AppColors.backgroundDark),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(
              title: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh'),
              ]),
          body: body,
        ),
      );
}

class TripChargesScreen extends StatefulWidget {
  const TripChargesScreen({super.key});
  @override
  State<TripChargesScreen> createState() => _TripChargesScreenState();
}

class _TripChargesScreenState extends State<TripChargesScreen> {
  List<Map<String, dynamic>> _charges = [];
  Map<String, dynamic> _summary = {};
  String? _label;
  int _days = 30;
  int _offset = 0;
  bool _loading = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await MonitoringService.fetchCharges(
        label: _label, days: _days, offset: append ? _offset : 0);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = 'Unable to load charges. Refresh to try again.';
        return;
      }
      final rows = MonitoringService.records(data['charges']);
      _charges = append ? [..._charges, ...rows] : rows;
      _summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
      _hasMore = data['has_more'] == true;
      _offset = (data['next_offset'] as num?)?.toInt() ?? 0;
    });
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
          const SizedBox(width: 12),
          Text(value,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ]),
      );

  @override
  Widget build(BuildContext context) => _MonitoringPage(
        title: 'Trip Additional Charges',
        onRefresh: _loading ? null : _load,
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                    initialValue: _label ?? 'All',
                    decoration: const InputDecoration(
                        labelText: 'Charge type', border: OutlineInputBorder()),
                    items: const [
                      'All',
                      'Tip',
                      'Baggage',
                      'Heavy items',
                      'Others'
                    ]
                        .map((label) =>
                            DropdownMenuItem(value: label, child: Text(label)))
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (label) {
                            setState(
                                () => _label = label == 'All' ? null : label);
                            _load();
                          }),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                    initialValue: _days,
                    decoration: const InputDecoration(
                        labelText: 'Period', border: OutlineInputBorder()),
                    items: [7, 30, 365]
                        .map((days) => DropdownMenuItem(
                            value: days, child: Text('Last $days days')))
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (days) {
                            if (days != null) {
                              setState(() => _days = days);
                              _load();
                            }
                          }),
                const SizedBox(height: 12),
                if (_summary.isNotEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            _line('Recorded charges',
                                '${_summary['charge_count'] ?? 0}'),
                            _line('Additional charges',
                                _money(_summary['total_amount']),
                                bold: true),
                            _line('Tips', _money(_summary['tip_amount'])),
                          ]))),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(12), child: Text(_error!)),
                if (!_loading && _error == null && _charges.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No additional charges in this period.')),
                ..._charges.map((charge) => Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  charge['label']?.toString() ??
                                      'Additional charge',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(
                                  '${charge['driver_name'] ?? 'Driver'} · ${charge['passenger_name'] ?? 'Passenger'}'),
                              const SizedBox(height: 4),
                              Text(
                                  '${charge['pickup_location'] ?? ''} → ${charge['destination'] ?? ''}'),
                              const SizedBox(height: 8),
                              _line('Base fare', _money(charge['base_fare'])),
                              _line(
                                  charge['label']?.toString() ??
                                      'Additional charge',
                                  _money(charge['amount']),
                                  bold: true),
                              _line('Total fare', _money(charge['total_fare']),
                                  bold: true),
                              const SizedBox(height: 8),
                              Text(charge['intent_confirmed'] == true
                                  ? 'Intentionally added by the passenger at booking.'
                                  : 'Legacy charge: no separate confirmation audit.'),
                              Text(
                                  '${charge['trip_status']} · ${charge['payment_status']} · ${_time(charge['added_at'])}'),
                              const SizedBox(height: 6),
                              SelectableText('Trip: ${charge['trip_id']}',
                                  style: const TextStyle(fontSize: 11)),
                            ])))),
                if (_loading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator())),
                if (_hasMore && !_loading)
                  TextButton(
                      onPressed: () => _load(append: true),
                      child: const Text('Load more charges')),
              ],
            )),
      );
}

class GpsActivityScreen extends StatefulWidget {
  final String? driverId;
  final String? tripId;
  final Map<String, dynamic>? initialLocation;
  const GpsActivityScreen(
      {super.key, this.driverId, this.tripId, this.initialLocation});
  @override
  State<GpsActivityScreen> createState() => _GpsActivityScreenState();
}

class _GpsActivityScreenState extends State<GpsActivityScreen> {
  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _cursor;
  GoogleMapController? _map;
  bool _loading = false;
  bool _hasMore = false;
  String? _error;
  int _days = 1;

  LatLng? _point(Map<String, dynamic>? row) {
    final lat = double.tryParse('${row?['latitude'] ?? row?['lat']}');
    final lng = double.tryParse('${row?['longitude'] ?? row?['lng']}');
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await MonitoringService.fetchGps(
        driverId: widget.driverId,
        tripId: widget.tripId,
        days: _days,
        cursor: append ? _cursor : null);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = 'Unable to load GPS activity. Refresh to try again.';
        return;
      }
      final rows = MonitoringService.records(data['locations']);
      _locations = append ? [..._locations, ...rows] : rows;
      _selected ??= rows.isEmpty ? null : rows.first;
      _hasMore = data['has_more'] == true;
      _cursor = data['next_cursor'] == null
          ? null
          : Map<String, dynamic>.from(data['next_cursor'] as Map);
    });
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  String _state(Map<String, dynamic> row) {
    final parts = <String>[
      if (row['within_service_area'] == false) 'Outside service area',
      if (row['route_deviation'] == true) 'Outside designated route',
      if (row['route_distance_m'] != null)
        '${(double.tryParse('${row['route_distance_m']}') ?? 0).round()} m from route',
      if (row['route_deviation'] == null) 'Route not recorded for this update',
    ];
    return parts.isEmpty ? 'Within service area and route' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final point = _point(_selected);
    return _MonitoringPage(
      title: 'GPS Activity',
      onRefresh: _loading ? null : _load,
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (point != null) ...[
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                        height: 220,
                        child: GoogleMap(
                            initialCameraPosition:
                                CameraPosition(target: point, zoom: 15),
                            onMapCreated: (controller) => _map = controller,
                            markers: {
                              Marker(
                                  markerId: const MarkerId('gps'),
                                  position: point)
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false))),
                const SizedBox(height: 8),
                SelectableText(
                    '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
                Text(_time(
                    _selected?['observed_at'] ?? _selected?['timestamp'])),
                TextButton.icon(
                    onPressed: () async {
                      final opened = await launchUrl(
                          Uri.https('www.google.com', '/maps/search/', {
                            'api': '1',
                            'query': '${point.latitude},${point.longitude}'
                          }),
                          mode: LaunchMode.externalApplication);
                      if (!opened && context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Unable to open maps.')));
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open location in Maps')),
              ],
              DropdownButtonFormField<int>(
                  initialValue: _days,
                  decoration: const InputDecoration(
                      labelText: 'GPS history', border: OutlineInputBorder()),
                  items: [1, 7, 30, 365]
                      .map((days) => DropdownMenuItem(
                          value: days,
                          child: Text(
                              days == 1 ? 'Last 24 hours' : 'Last $days days')))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (days) {
                          if (days != null) {
                            setState(() => _days = days);
                            _load();
                          }
                        }),
              const SizedBox(height: 12),
              const Text(
                  'Received GPS updates are logged while drivers are online or on a trip.'),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(12), child: Text(_error!)),
              if (!_loading && _error == null && _locations.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No GPS updates in this period.')),
              ..._locations.map((row) => Card(
                      child: ListTile(
                    onTap: () {
                      final target = _point(row);
                      setState(() => _selected = row);
                      if (target != null)
                        _map?.animateCamera(CameraUpdate.newLatLng(target));
                    },
                    leading: Icon(row['route_deviation'] == true ||
                            row['within_service_area'] == false
                        ? Icons.warning_amber_rounded
                        : Icons.location_on_outlined),
                    title: Text(
                        '${row['driver_name'] ?? 'Driver'} · ${row['plate_no'] ?? row['toda_body_number'] ?? 'Tricycle'}'),
                    subtitle: Text(
                        '${_time(row['observed_at'] ?? row['timestamp'])}\n'
                        '${row['latitude']}, ${row['longitude']}\n${_state(row)}'
                        '${row['trip_id'] == null ? '' : '\nTrip: ${row['trip_id']}'}'),
                  ))),
              if (_loading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator())),
              if (_hasMore && !_loading)
                TextButton(
                    onPressed: () => _load(append: true),
                    child: const Text('Load more GPS updates')),
            ],
          )),
    );
  }
}
