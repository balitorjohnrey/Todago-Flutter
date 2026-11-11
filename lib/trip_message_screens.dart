import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'trip_service.dart';

const _ink = AppColors.backgroundDark;
const _pageColor = Color(0xFFF1F3F6);

List<Map<String, dynamic>> _rows(dynamic value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

String _dateTimeLabel(BuildContext context, dynamic value,
    {bool dateOnly = false}) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  final localizations = MaterialLocalizations.of(context);
  final day = localizations.formatShortDate(date);
  if (dateOnly) return day;
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  return '$day · $time';
}

class TripMessagesButton extends StatelessWidget {
  final bool forDriver;

  const TripMessagesButton({super.key, this.forDriver = false});

  @override
  Widget build(BuildContext context) => FloatingActionButton(
        heroTag: null,
        tooltip: 'Messages',
        backgroundColor: forDriver ? AppColors.primary : _ink,
        foregroundColor: forDriver ? _ink : AppColors.primary,
        onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => TripInboxScreen(forDriver: forDriver),
        )),
        child: const Icon(Icons.forum_rounded),
      );
}

class TripInboxScreen extends StatefulWidget {
  final bool forDriver;

  const TripInboxScreen({super.key, required this.forDriver});

  @override
  State<TripInboxScreen> createState() => _TripInboxScreenState();
}

class _TripInboxScreenState extends State<TripInboxScreen> {
  List<Map<String, dynamic>> _conversations = [];
  Map<String, String>? _cursor;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await TripService.getConversations(
      forDriver: widget.forDriver,
      cursor: more ? _cursor : null,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = result['success'] != true;
      if (_failed) return;
      final rows = _rows(result['conversations']);
      if (more) {
        final loaded = _conversations.map((row) => row['trip_id']).toSet();
        _conversations
            .addAll(rows.where((row) => !loaded.contains(row['trip_id'])));
      } else {
        _conversations = rows;
      }
      final cursor = result['nextCursor'];
      _cursor = cursor is Map ? Map<String, String>.from(cursor) : null;
    });
  }

  Future<void> _open(String tripId) async {
    await TripConversationScreen.open(context,
        tripId: tripId, forDriver: widget.forDriver);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _pageColor,
        appBar: AppBar(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          title: const Text('Messages'),
          actions: [
            IconButton(
                tooltip: 'Refresh messages',
                onPressed: _load,
                icon: const Icon(Icons.refresh)),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final row in _conversations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF1D1),
                          foregroundColor: _ink,
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        title: Text(
                          row['peer_name']?.toString() ??
                              (widget.forDriver ? 'Passenger' : 'Driver'),
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (row['destination'] case final String destination
                                when destination.isNotEmpty)
                              Text(destination,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textHint, fontSize: 12)),
                            Text(
                              row['last_message']?.toString() ??
                                  'Start a conversation',
                              style: const TextStyle(color: _ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                                _dateTimeLabel(context, row['activity_at'],
                                    dateOnly: true),
                                style: const TextStyle(
                                    color: AppColors.textHint, fontSize: 11)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () => _open(row['trip_id'].toString()),
                      ),
                    ),
                  ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_failed)
                  _MessageLoadError(
                      text: 'Could not load conversations.', retry: _load)
                else if (_conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 12),
                    child: Column(children: [
                      const Icon(Icons.forum_outlined,
                          size: 36, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      const Text('No conversations yet',
                          style: TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        widget.forDriver
                            ? 'Accept a trip to message the passenger.'
                            : 'You can message your driver once they accept your trip.',
                        style: const TextStyle(color: AppColors.textHint),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                if (!_loading && _cursor != null)
                  TextButton(
                    onPressed: () => _load(more: true),
                    child: const Text('Load older conversations',
                        style: TextStyle(color: _ink)),
                  ),
              ],
            ),
          ),
        ),
      );
}

class TripConversationScreen extends StatefulWidget {
  final String tripId;
  final bool forDriver;

  const TripConversationScreen({
    super.key,
    required this.tripId,
    required this.forDriver,
  });

  static Future<void> open(
    BuildContext context, {
    required String? tripId,
    required bool forDriver,
  }) async {
    if (tripId == null || tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trip conversation is unavailable.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) =>
          TripConversationScreen(tripId: tripId, forDriver: forDriver),
    ));
  }

  @override
  State<TripConversationScreen> createState() => _TripConversationScreenState();
}

class _TripConversationScreenState extends State<TripConversationScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  Timer? _pollTimer;
  Future<void>? _pendingLoad;
  Map<String, dynamic>? _conversation;
  List<Map<String, dynamic>> _messages = [];
  String? _cursor;
  String? _loadError;
  String? _sendError;
  String? _submittedText;
  String? _requestId;
  bool _sending = false;

  bool get _canSend => _conversation?['can_send'] == true;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (ModalRoute.of(context)?.isCurrent == true &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({String? before}) =>
      _pendingLoad ??= _fetch(before).whenComplete(() {
        _pendingLoad = null;
      });

  Future<void> _fetch(String? before) async {
    final result = await TripService.getTripMessages(widget.tripId,
        forDriver: widget.forDriver, before: before);
    if (!mounted) return;
    final conversation = result['conversation'];
    if (result['success'] != true || conversation is! Map<String, dynamic>) {
      setState(() => _loadError = 'Could not load messages.');
      return;
    }
    final page = _rows(result['messages']);
    final next = result['nextCursor']?.toString();
    setState(() {
      _conversation = conversation;
      _loadError = null;
      if (before != null) {
        _messages.addAll(page);
        _cursor = next;
        return;
      }

      // Keep older pages when the refreshed page overlaps what is on screen.
      final overlap = page.isEmpty
          ? -1
          : _messages.indexWhere(
              (row) => row['message_id'] == page.last['message_id']);
      if (overlap >= 0) {
        _messages = [...page, ..._messages.skip(overlap + 1)];
      } else {
        _messages = page;
        _cursor = next;
      }
    });
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (!_canSend || _sending || text.isEmpty) return;
    if (_submittedText != text) {
      final random = Random.secure();
      _requestId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _submittedText = text;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final result = await TripService.sendTripMessage(widget.tripId,
        forDriver: widget.forDriver, text: text, requestId: _requestId!);
    if (!mounted) return;
    final sent = result['success'] == true;
    if (sent) {
      _draft.clear();
      _submittedText = null;
      _requestId = null;
    }
    setState(() {
      _sending = false;
      if (!sent) {
        _sendError = result['message']?.toString() ??
            'Could not send the message. Try again.';
      }
    });
    final pending = _pendingLoad;
    if (pending != null) await pending;
    if (!mounted) return;
    await _load();
    if (sent && mounted && _scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final peer = _conversation?['peer_name']?.toString();
    final destination = _conversation?['destination']?.toString() ?? '';
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: _pageColor,
        appBar: AppBar(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(peer ?? 'Trip conversation',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (destination.isNotEmpty)
              Text(destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          actions: [
            IconButton(
                tooltip: 'Refresh messages',
                onPressed: _load,
                icon: const Icon(Icons.refresh)),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            if (_loadError case final String error)
              _MessageLoadError(text: error, retry: _load),
            Expanded(child: _buildHistory()),
            if (_canSend)
              _buildComposer()
            else if (_conversation != null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('This trip conversation is closed.',
                    style: TextStyle(color: AppColors.textHint)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_conversation == null) {
      return Center(
          child: _loadError == null ? const CircularProgressIndicator() : null);
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet',
            style: TextStyle(color: AppColors.textHint)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_cursor == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return TextButton(
            onPressed: () => _load(before: _cursor),
            child: const Text('Load older messages',
                style: TextStyle(color: _ink)),
          );
        }
        final message = _messages[index];
        final mine = message['sender_role'] ==
            (widget.forDriver ? 'driver' : 'passenger');
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .76),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? _ink : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(message['body']?.toString() ?? '',
                      style: TextStyle(
                          color: mine ? Colors.white : _ink, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(_dateTimeLabel(context, message['created_at']),
                      style: TextStyle(
                          color: mine ? Colors.white70 : AppColors.textHint,
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() => Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_sendError case final String error)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child:
                    Text(error, style: const TextStyle(color: AppColors.error)),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _draft,
                  readOnly: _sending,
                  maxLength: 500,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: _ink),
                  cursorColor: _ink,
                  decoration: InputDecoration(
                    hintText: 'Write a message',
                    counterText: '',
                    fillColor: _pageColor,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _draft,
                builder: (_, draft, __) => IconButton.filled(
                  tooltip: 'Send message',
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: _ink),
                  onPressed:
                      _sending || draft.text.trim().isEmpty ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ]),
          ]),
        ),
      );
}

class _MessageLoadError extends StatelessWidget {
  final String text;
  final VoidCallback retry;

  const _MessageLoadError({required this.text, required this.retry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(text, style: const TextStyle(color: _ink))),
          TextButton(
            onPressed: retry,
            child: const Text('Retry',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}
