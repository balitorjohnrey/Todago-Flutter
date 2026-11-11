import 'dart:math';

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
  static const _warning = Color(0xFFB42318);
  static const _warningSurface = Color(0xFFFFF1F0);
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
    return lat == null ||
            lng == null ||
            !lat.isFinite ||
            !lng.isFinite ||
            lat.abs() > 90 ||
            lng.abs() > 180
        ? null
        : LatLng(lat, lng);
  }

  String _coordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

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
      if (!append) {
        final id = _selected?['location_id'];
        final updated =
            rows.where((row) => id != null && row['location_id'] == id);
        if (updated.isNotEmpty) {
          _selected = updated.first;
        } else if (_selected == null || _selected != widget.initialLocation) {
          _selected = rows.isEmpty ? null : rows.first;
        }
      }
      _hasMore = data['has_more'] == true;
      _cursor = data['next_cursor'] == null
          ? null
          : Map<String, dynamic>.from(data['next_cursor'] as Map);
    });
    final point = _point(_selected);
    if (point == null) {
      _map = null;
    } else if (!append) {
      _map?.animateCamera(CameraUpdate.newLatLng(point));
    }
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  String _areaStatus(Map<String, dynamic> row) {
    if (row['within_service_area'] == false) return 'Outside service area';
    if (row['within_service_area'] != true) return 'Service area unavailable';
    return row['service_area_name']?.toString() ?? 'Within service area';
  }

  String _routeStatus(Map<String, dynamic> row) {
    final deviation = row['route_deviation'];
    if (deviation == null) return 'Route not recorded for this update';
    final distance = double.tryParse('${row['route_distance_m']}');
    return [
      deviation == true
          ? 'Outside designated route'
          : 'Within designated route',
      if (distance != null && distance.isFinite)
        '${distance.round()} m from route',
    ].join(' · ');
  }

  String _allowedAreas(Map<String, dynamic> row) {
    final areas = row['allowed_service_areas'];
    return areas is List ? areas.whereType<String>().join(' and ') : '';
  }

  Future<void> _openMaps(LatLng point) async {
    final opened = await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${point.latitude},${point.longitude}',
      }),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to open maps.')));
    }
  }

  Future<void> _openDetails(
      BuildContext tileContext, Map<String, dynamic> row) async {
    final point = _point(row);
    setState(() => _selected = row);
    if (point != null) _map?.animateCamera(CameraUpdate.newLatLng(point));
    final outside = row['within_service_area'] == false;
    final areas = _allowedAreas(row);
    final driver = row['driver_name']?.toString() ?? 'Driver';
    final locationId = row['location_id']?.toString();
    final sent = await showModalBottomSheet<bool>(
      context: tileContext,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  children: [
                    Text('GPS update details',
                        style: Theme.of(sheetContext).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(driver,
                        style: Theme.of(sheetContext).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _detail('Service area', _areaStatus(row),
                        color: outside ? _warning : null),
                    if (outside && areas.isNotEmpty)
                      _detail('Allowed areas', areas),
                    _detail('Recorded at',
                        _time(row['observed_at'] ?? row['timestamp'])),
                    if (point != null)
                      _detail('Coordinates', _coordinates(point)),
                    if (row['plate_no'] != null)
                      _detail('Plate number', '${row['plate_no']}'),
                    if (row['toda_body_number'] != null)
                      _detail('Body number', '${row['toda_body_number']}'),
                    if (row['association_name'] != null)
                      _detail('TODA', '${row['association_name']}'),
                    _detail('Route', _routeStatus(row)),
                    _detail(
                        'Activity',
                        switch (row['source']) {
                          'online_driver_location' => 'Online location update',
                          'active_trip' => 'Trip location update',
                          _ => 'GPS location update',
                        }),
                    if (row['trip_id'] != null)
                      _detail('Trip ID', '${row['trip_id']}'),
                    if (point != null)
                      OutlinedButton.icon(
                        onPressed: () => _openMaps(point),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open location in Maps'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: row['can_message_driver'] == true && locationId != null
                      ? FilledButton.icon(
                          onPressed: () async {
                            final delivered = await showDialog<bool>(
                              context: sheetContext,
                              barrierDismissible: false,
                              builder: (_) => _GpsMessageDialog(
                                locationId: locationId,
                                driver: driver,
                                draft: outside
                                    ? 'Your GPS location was outside the TodaGo service area. Please return to the service area${areas.isEmpty ? '' : ' ($areas)'}.'
                                    : '',
                              ),
                            );
                            if (delivered == true && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          },
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Message driver'),
                        )
                      : const Text(
                          'Messaging is unavailable for this GPS update.',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Message sent to $driver.')));
    }
  }

  Widget _detail(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            SelectableText(value, style: TextStyle(color: color)),
          ],
        ),
      );

  Widget _locationCard(BuildContext tileContext, Map<String, dynamic> row) {
    final outside = row['within_service_area'] == false;
    final point = _point(row);
    return Card(
      color: outside ? _warningSurface : Colors.white,
      shape: outside
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFF1A9A4)),
            )
          : null,
      child: ListTile(
        onTap: () => _openDetails(tileContext, row),
        leading: Icon(
          outside || row['route_deviation'] == true
              ? Icons.warning_amber_rounded
              : Icons.location_on_outlined,
          color: outside ? _warning : null,
        ),
        title: Text('${row['driver_name'] ?? 'Driver'} · '
            '${row['plate_no'] ?? row['toda_body_number'] ?? 'Tricycle'}'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_areaStatus(row),
                  style: outside
                      ? const TextStyle(
                          color: _warning, fontWeight: FontWeight.bold)
                      : null),
              Text(_time(row['observed_at'] ?? row['timestamp'])),
              if (point != null) Text(_coordinates(point)),
              Text(_routeStatus(row)),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
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
                                  position: point,
                                  icon: _selected?['within_service_area'] ==
                                          false
                                      ? BitmapDescriptor.defaultMarker
                                      : BitmapDescriptor.defaultMarkerWithHue(
                                          BitmapDescriptor.hueAzure))
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false))),
                const SizedBox(height: 8),
                if (_selected?['within_service_area'] == false)
                  const Text('Outside service area',
                      style: TextStyle(
                          color: _warning, fontWeight: FontWeight.bold)),
                SelectableText(_coordinates(point)),
                Text(_time(
                    _selected?['observed_at'] ?? _selected?['timestamp'])),
                TextButton.icon(
                    onPressed: () => _openMaps(point),
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
              for (final row in _locations)
                Builder(
                    builder: (tileContext) => _locationCard(tileContext, row)),
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

class _GpsMessageDialog extends StatefulWidget {
  const _GpsMessageDialog({
    required this.locationId,
    required this.driver,
    required this.draft,
  });

  final String locationId;
  final String driver;
  final String draft;

  @override
  State<_GpsMessageDialog> createState() => _GpsMessageDialogState();
}

class _GpsMessageDialogState extends State<_GpsMessageDialog> {
  late final TextEditingController _message =
      TextEditingController(text: widget.draft);
  bool _sending = false;
  String? _error;
  String? _requestId;
  String? _submittedText;

  Future<void> _send() async {
    final text = _message.text.trim();
    if (_sending || text.isEmpty) return;
    if (_submittedText != text) {
      final random = Random.secure();
      _requestId = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      _submittedText = text;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await MonitoringService.sendGpsMessage(
        widget.locationId, text, _requestId!);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
    if (error == null) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sending,
        child: AlertDialog(
          title: const Text('Message driver'),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To: ${widget.driver}'),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                enabled: !_sending,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            FilledButton(
                onPressed:
                    _sending || _message.text.trim().isEmpty ? null : _send,
                child: Text(_sending ? 'Sending…' : 'Send message')),
          ],
        ),
      );
}
