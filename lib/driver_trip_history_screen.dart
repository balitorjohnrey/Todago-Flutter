import 'package:flutter/material.dart';

import 'rate_passenger_screen.dart';
import 'report_issue_dialog.dart';
import 'trip_service.dart';

class DriverTripHistoryScreen extends StatefulWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  State<DriverTripHistoryScreen> createState() =>
      _DriverTripHistoryScreenState();
}

class _DriverTripHistoryScreenState extends State<DriverTripHistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await TripService.getDriverHistory();
    if (!mounted) return;
    setState(() {
      _trips = trips
          .where((trip) =>
              trip['status'] == 'completed' && trip['payment_status'] == 'paid')
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Past Trips')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_trips.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No completed, paid trips yet.')),
                    ..._trips.map((trip) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    trip['commuter_name']?.toString() ??
                                        'Passenger',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    '${trip['pickup_location'] ?? 'Pickup'} → ${trip['destination'] ?? 'Destination'}'),
                                const SizedBox(height: 4),
                                Text(DateTime.tryParse(trip['request_timestamp']
                                                ?.toString() ??
                                            '')
                                        ?.toLocal()
                                        .toString()
                                        .split('.')
                                        .first ??
                                    ''),
                                if (trip['passenger_rating_score'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      'Your passenger rating: ${trip['passenger_rating_score']}/5'),
                                ],
                                const SizedBox(height: 12),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  RatePassengerScreen(
                                                      trip: trip)));
                                      if (mounted) await _load();
                                    },
                                    icon: const Icon(Icons.star_rounded,
                                        size: 18),
                                    label: Text(
                                        trip['passenger_rating_score'] == null
                                            ? 'Rate Passenger'
                                            : 'View Rating'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => showReportIssueDialog(
                                      context: context,
                                      reporterRole: 'driver',
                                      initialType: 'passenger_issue',
                                      tripId: trip['trip_id']?.toString(),
                                      subjectRole: 'passenger',
                                      subjectId:
                                          trip['commuter_id']?.toString(),
                                      subjectName:
                                          trip['commuter_name']?.toString(),
                                    ),
                                    icon: const Icon(
                                        Icons.report_problem_outlined,
                                        size: 18),
                                    label: const Text('Report Passenger'),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
      );
}
