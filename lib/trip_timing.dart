import 'package:flutter/material.dart';

class TripTiming extends StatelessWidget {
  const TripTiming({super.key, required this.trip, this.color});

  final Map<String, dynamic> trip;
  final Color? color;

  DateTime? _parseTime(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  DateTime? _dropoffTime() {
    final recordedTime = _parseTime(trip['dropped_off_at']);
    if (recordedTime != null) return recordedTime;

    final stops = trip['shared_dropoffs'];
    if (stops is List &&
        stops.isNotEmpty &&
        stops.every((stop) => stop is Map && stop['status'] == 'dropped')) {
      return _parseTime((stops.last as Map)['dropped_at']);
    }
    return null;
  }

  String _formatTime(BuildContext context, DateTime time) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(time);
    final clock = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date, $clock';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return [
      if (duration.inHours > 0) '${duration.inHours} hr',
      if (minutes > 0) '$minutes min',
      if (seconds > 0 || duration.inSeconds == 0) '$seconds sec',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _parseTime(trip['picked_up_at']);
    final dropoff = _dropoffTime();
    final duration =
        pickup == null || dropoff == null ? null : dropoff.difference(pickup);

    return DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      child: pickup == null && dropoff == null
          ? const Text('Ride timing unavailable')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickup == null
                    ? 'Pickup time unavailable'
                    : 'Picked up ${_formatTime(context, pickup)}'),
                Text(dropoff == null
                    ? 'Drop-off time unavailable'
                    : 'Dropped off ${_formatTime(context, dropoff)}'),
                if (duration != null && !duration.isNegative)
                  Text('Trip duration ${_formatDuration(duration)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
    );
  }
}
