import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReservationNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'todago_reservations';
  static const _channelName = 'Scheduled reservations';
  static const _channelDescription =
      'Reminders for upcoming TodaGo scheduled reservations';
  static const _reminderMinutes = [60, 30, 5];

  static Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Singapore'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> scheduleForTrips(
    Iterable<Map<String, dynamic>> trips, {
    required bool forDriver,
  }) async {
    await initialize();
    for (final trip in trips) {
      await scheduleReservationReminders(trip, forDriver: forDriver);
    }
  }

  static Future<void> scheduleReservationReminders(
    Map<String, dynamic> trip, {
    required bool forDriver,
  }) async {
    await initialize();

    final tripId = trip['trip_id']?.toString() ?? '';
    final scheduledAt = _scheduledAt(trip);
    if (tripId.isEmpty || scheduledAt == null) return;

    final now = DateTime.now();
    final titleName = forDriver
        ? (trip['commuter_name']?.toString() ?? 'Passenger')
        : (trip['driver_name']?.toString() ?? 'Driver');
    final pickup = trip['pickup_location']?.toString() ?? 'pickup';
    final destination = trip['destination']?.toString() ?? 'destination';
    final roleText = forDriver ? 'passenger' : 'driver';

    for (final minutes in _reminderMinutes) {
      final notifyAt = scheduledAt.subtract(Duration(minutes: minutes));
      final id = _notificationId(tripId, minutes, forDriver);
      await _notifications.cancel(id);
      if (!notifyAt.isAfter(now)) continue;

      await _notifications.zonedSchedule(
        id,
        'TodaGo reservation in ${_label(minutes)}',
        '$titleName is your $roleText for $pickup to $destination at ${_timeText(scheduledAt)}.',
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reservation:$tripId:$minutes',
      );
    }
  }

  static Future<void> cancelForTrip(String tripId,
      {required bool forDriver}) async {
    if (tripId.isEmpty) return;
    await initialize();
    for (final minutes in _reminderMinutes) {
      await _notifications.cancel(_notificationId(tripId, minutes, forDriver));
    }
  }

  static DateTime? _scheduledAt(Map<String, dynamic> trip) {
    final raw = trip['scheduled_pickup_at']?.toString();
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static int _notificationId(String tripId, int minutes, bool forDriver) {
    var hash = forDriver ? 17 : 29;
    for (final codeUnit in tripId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return (hash + minutes * 1000) & 0x7fffffff;
  }

  static String _label(int minutes) {
    if (minutes >= 60) return '${minutes ~/ 60} hour';
    return '$minutes minutes';
  }

  static String _timeText(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
