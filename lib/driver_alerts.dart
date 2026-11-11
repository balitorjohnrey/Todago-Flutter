import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DriverAlerts {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static final outsideServiceArea = ValueNotifier<String?>(null);
  static final _notifiedMessages = <String>{};
  static const _serviceAreaId = -1020;
  static const _adminMessageId = -1021;
  static DateTime? _lastObservation;
  static int _session = 0;

  static int get session => _session;

  static void applyServiceArea(Object? value, int session) {
    if (session != _session || value is! Map) return;
    final withinArea = value['within_service_area'];
    final observed = DateTime.tryParse('${value['observed_at']}');
    if (withinArea is! bool ||
        observed == null ||
        (_lastObservation != null && !observed.isAfter(_lastObservation!))) {
      return;
    }
    final firstObservation = _lastObservation == null;
    _lastObservation = observed;
    if (withinArea) {
      _dismissServiceAreaWarning(clearNotification: firstObservation);
      return;
    }
    final areas = value['allowed_service_areas'];
    final names = areas is List ? areas.whereType<String>().join(' or ') : '';
    final message = names.isEmpty
        ? 'Please return to the TodaGo service area.'
        : 'Please return to $names to provide TodaGo service.';
    final alreadyOutside = outsideServiceArea.value != null;
    outsideServiceArea.value = message;
    if (!alreadyOutside) {
      unawaited(_show(_serviceAreaId, 'Outside service area', message));
    }
  }

  static void clearServiceArea() {
    _session++;
    _lastObservation = null;
    _dismissServiceAreaWarning(clearNotification: true);
  }

  static void _dismissServiceAreaWarning({required bool clearNotification}) {
    final wasOutside = outsideServiceArea.value != null;
    outsideServiceArea.value = null;
    if (wasOutside || clearNotification) unawaited(_cancel(_serviceAreaId));
  }

  static bool notifyUnreadMessages(Iterable<String> ids) {
    var hasNew = false;
    for (final id in ids) {
      if (_notifiedMessages.add(id)) hasNew = true;
    }
    if (hasNew) {
      unawaited(_show(_adminMessageId, 'Message from TodaGo Admin',
          'Open Admin messages in the driver app to read it.'));
    }
    return hasNew;
  }

  static Future<void> _show(int id, String title, String message) async {
    try {
      await _notifications.show(
        id,
        title,
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todago_driver_alerts',
            'Driver alerts',
            channelDescription:
                'Service area warnings and messages from TodaGo Admin',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // The in-app warning and inbox work without notification permission.
    }
  }

  static Future<void> _cancel(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (_) {}
  }
}

class DriverServiceAreaWarning extends StatelessWidget {
  const DriverServiceAreaWarning({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: DriverAlerts.outsideServiceArea,
        builder: (context, message, _) => message == null
            ? const SizedBox.shrink()
            : Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    border: Border.all(color: const Color(0xFFF1A9A4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFB42318)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Outside service area\n',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: message,
                                style: const TextStyle(
                                    fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                              color: Color(0xFF8A1B13), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
}
