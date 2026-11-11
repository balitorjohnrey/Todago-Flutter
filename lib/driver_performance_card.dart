import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'monitoring_service.dart';
import 'profile_avatar.dart';

double _number(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

String _rating(Map<String, dynamic> driver) =>
    _number(driver['rating_count']) == 0
        ? 'Unrated'
        : '${_number(driver['avg_rating']).toStringAsFixed(2)} / 5';

String _completedTrips(Map<String, dynamic> driver) =>
    '${_number(driver['total_trips']).toInt()} completed trips';

String _ratingCount(Map<String, dynamic> driver) =>
    '${_number(driver['rating_count']).toInt()} ratings';

class DriverPerformanceCard extends StatelessWidget {
  final List<Map<String, dynamic>>? drivers;
  final bool operator;
  const DriverPerformanceCard(
      {super.key, required this.drivers, this.operator = false});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE8EDF2))),
        textStyle: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(color: AppColors.backgroundDark, fontSize: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.star_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Top Rated Drivers',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            const SizedBox(height: 6),
            const Text('Average passenger rating and completed trips',
                style: TextStyle(color: AppColors.textHint, fontSize: 11)),
            const SizedBox(height: 12),
            if (drivers == null)
              const Text(
                  'Unable to load driver performance. Refresh to try again.')
            else if (drivers!.isEmpty)
              const Text('No driver performance records yet.')
            else
              ...drivers!.asMap().entries.map((entry) {
                final driver = entry.value;
                final id = driver['driver_id']?.toString();
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: id == null || id.isEmpty
                      ? null
                      : () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: Colors.white,
                            builder: (_) => _DriverProfileSheet(
                                id: id, summary: driver, operator: operator),
                          ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('${entry.key + 1}.',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    driver['driver_name']?.toString() ??
                                        'Driver',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            Text(_rating(driver),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            if (id != null && id.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textHint, size: 18),
                            ],
                          ]),
                          const SizedBox(height: 5),
                          Wrap(spacing: 12, runSpacing: 4, children: [
                            Text(_completedTrips(driver)),
                            Text(_ratingCount(driver)),
                            if (driver['toda_body_number'] != null)
                              Text('Body ${driver['toda_body_number']}'),
                          ]),
                          if (driver['association_name'] != null) ...[
                            const SizedBox(height: 4),
                            Text(driver['association_name'].toString(),
                                style:
                                    const TextStyle(color: AppColors.textHint)),
                          ],
                        ]),
                  ),
                );
              }),
          ]),
        ),
      );
}

class _DriverProfileSheet extends StatefulWidget {
  final String id;
  final Map<String, dynamic> summary;
  final bool operator;

  const _DriverProfileSheet({
    required this.id,
    required this.summary,
    required this.operator,
  });

  @override
  State<_DriverProfileSheet> createState() => _DriverProfileSheetState();
}

class _DriverProfileSheetState extends State<_DriverProfileSheet> {
  late Future<Map<String, dynamic>?> _profile = _fetch();

  Future<Map<String, dynamic>?> _fetch() =>
      MonitoringService.fetchDriverProfile(widget.id,
          operator: widget.operator);

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _profile,
          builder: (context, snapshot) {
            final details = snapshot.data;
            final driver = details ?? widget.summary;
            final name = driver['driver_name']?.toString().trim() ?? 'Driver';
            final initials = name
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part.characters.first.toUpperCase())
                .join();
            final status = switch (driver['status']) {
              'online' => 'Online',
              'offline' => 'Offline',
              'on_trip' => 'On a trip',
              'suspended' => 'Suspended',
              _ => null,
            };
            final fields = {
              'Phone': driver['phone'],
              'Email': driver['email'],
              'TODA association': driver['association_name'] ??
                  (details == null ? null : 'Independent'),
              'Body number': driver['toda_body_number'],
              'Plate number': driver['plate_no'],
              'Vehicle color': driver['vehicle_color'],
              'Status': status,
              if (driver['is_verified'] is bool)
                'Application':
                    driver['is_verified'] == true ? 'Approved' : 'Pending',
            };
            return DefaultTextStyle(
              style:
                  (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(color: AppColors.backgroundDark),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Driver profile',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18))),
                    IconButton(
                      tooltip: 'Close profile',
                      color: AppColors.backgroundDark,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    ProfileAvatar(
                        initials: initials,
                        size: 60,
                        imagePath: driver['profile_photo_url']?.toString()),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 16),
                  Wrap(spacing: 12, runSpacing: 6, children: [
                    Text(_rating(widget.summary),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_ratingCount(widget.summary)),
                    Text(_completedTrips(widget.summary)),
                  ]),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator()
                  else if (details == null)
                    TextButton(
                      onPressed: () => setState(() => _profile = _fetch()),
                      child: const Text(
                          'Could not load the full profile. Retry',
                          style: TextStyle(color: AppColors.backgroundDark)),
                    ),
                  for (final field in fields.entries)
                    if (field.value != null &&
                        field.value.toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field.key,
                                  style: const TextStyle(
                                      color: AppColors.textHint, fontSize: 12)),
                              Text(field.value.toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                ],
              ),
            );
          },
        ),
      );
}
