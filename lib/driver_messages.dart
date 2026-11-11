import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'driver_auth_service.dart';

class DriverMessage {
  const DriverMessage(this.id, this.body, this.createdAt, this.unread);

  final String id;
  final String body;
  final DateTime? createdAt;
  final bool unread;
}

class DriverMessages {
  static const _endpoint =
      'https://todago-backend-production.up.railway.app/api/driver/messages';

  static Future<List<DriverMessage>?> fetch() async {
    try {
      final token = await DriverAuthService.getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse(_endpoint),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final messages = data['messages'];
      if (data['success'] != true || messages is! List) return null;
      return [
        for (final row in messages.whereType<Map>())
          if (row['message_id'] is String && row['body'] is String)
            DriverMessage(
              row['message_id'] as String,
              row['body'] as String,
              DateTime.tryParse('${row['created_at']}')?.toLocal(),
              row['read_at'] == null,
            ),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<bool> markRead(String messageId) async {
    try {
      final token = await DriverAuthService.getToken();
      if (token == null) return false;
      final response = await http.patch(
        Uri.parse('$_endpoint/${Uri.encodeComponent(messageId)}/read'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class DriverMessagesScreen extends StatefulWidget {
  const DriverMessagesScreen({super.key});

  @override
  State<DriverMessagesScreen> createState() => _DriverMessagesScreenState();
}

class _DriverMessagesScreenState extends State<DriverMessagesScreen> {
  List<DriverMessage> _messages = [];
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messages = await DriverMessages.fetch();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = messages == null;
      if (messages != null) _messages = messages;
    });
  }

  String _time(DateTime? date) {
    if (date == null) return 'Time unavailable';
    final format = MaterialLocalizations.of(context);
    return '${format.formatMediumDate(date)} · ${format.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  Future<void> _open(DriverMessage message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('TodaGo Admin'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_time(message.createdAt)),
            const SizedBox(height: 12),
            SelectableText(message.body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!mounted || !message.unread) return;
    final ok = await DriverMessages.markRead(message.id);
    if (!mounted) return;
    if (ok) {
      // Keep the message visible even if the subsequent refresh fails.
      setState(() => _messages = [
            for (final row in _messages)
              if (row.id == message.id)
                DriverMessage(row.id, row.body, row.createdAt, false)
              else
                row,
          ]);
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark the message as read.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin messages'), actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ]),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_failed)
                const ListTile(
                    title: Text('Could not load messages. Pull down to retry.'))
              else if (_messages.isEmpty && !_loading)
                const ListTile(
                    title: Text('No messages from TodaGo Admin yet.')),
              for (final message in _messages)
                Card(
                  child: ListTile(
                    onTap: () => _open(message),
                    leading: Icon(message.unread
                        ? Icons.mark_email_unread_outlined
                        : Icons.drafts_outlined),
                    title: Text(
                        message.unread ? 'TodaGo Admin · New' : 'TodaGo Admin'),
                    subtitle: Text(
                        '${_time(message.createdAt)}\n${message.body}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ],
          ),
        ),
      );
}
