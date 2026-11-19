import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'book_destination_button.dart';
import 'booking_destination.dart';
import 'faq_service.dart';
import 'live_map_screen.dart';
import 'location_query.dart';
import 'map_service.dart';

class _Msg {
  final String id;
  final String text;
  final bool isUser;
  final bool isTyping;
  final DateTime time;
  final String? routeQuery;
  final BookingDestination? bookingDestination;
  final FaqEntry? faq;

  _Msg({
    required this.id,
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.routeQuery,
    this.bookingDestination,
    this.faq,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class AIChatScreen extends StatefulWidget {
  final String userType;
  final String userName;

  const AIChatScreen({
    super.key,
    required this.userType,
    required this.userName,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  final List<_Msg> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  final SpeechToText _speech = SpeechToText();
  bool _speechReady = false;
  bool _isListening = false;
  bool _sending = false;
  bool _showChips = true;
  late AnimationController _pulse;

  List<String> get _chips => FaqService.quickQuestions(widget.userType)
      .map((faq) => faq.question)
      .toList();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _addGreeting());
  }

  void _addGreeting() {
    final firstName = widget.userName.trim().split(' ').first;
    final role = widget.userType.toLowerCase();
    final roleText = role == 'driver' || role == 'passenger' ? '$role ' : '';
    setState(() {
      _messages.add(_Msg(
        id: 'greeting',
        text:
            'Hi $firstName! I can answer TodaGo ${roleText}FAQs and find routes to places. Ask for directions or choose a quick question.',
        isUser: false,
      ));
    });
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _onSpeechDone();
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _pulse.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;

    _ctrl.clear();
    _focus.unfocus();
    setState(() {
      _sending = true;
      _showChips = false;
      _messages.add(_Msg(
        id: UniqueKey().toString(),
        text: text,
        isUser: true,
      ));
      _messages.add(_Msg(
        id: 'typing-${DateTime.now().microsecondsSinceEpoch}',
        text: '',
        isUser: false,
        isTyping: true,
      ));
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final explicitLocation = locationQueryFromMessage(text);
    // Place names can contain a broad FAQ term, such as "Maya Hotel".
    // Overriding an explicit place request needs a specific FAQ phrase.
    final faq = FaqService.match(text, widget.userType,
        minKeywordWords: explicitLocation == null ? 1 : 2);
    final location = explicitLocation != null &&
            (faq == null || faq.category == 'directions')
        ? explicitLocation
        : faq == null && looksLikeStandalonePlace(text)
            ? text
            : null;
    final response = location == null
        ? _Msg(
            id: UniqueKey().toString(),
            text: faq?.answer ?? FaqService.fallbackAnswer(widget.userType),
            isUser: false,
            faq: faq)
        : await _routeReply(location);
    if (!mounted) return;
    setState(() {
      final idx = _messages.lastIndexWhere((msg) => msg.isTyping);
      if (idx != -1) {
        _messages[idx] = response;
      }
      _sending = false;
    });
    _scrollToBottom();
  }

  Future<_Msg> _routeReply(String query) async {
    _Msg reply(String text,
            {String? routeQuery, BookingDestination? bookingDestination}) =>
        _Msg(
          id: UniqueKey().toString(),
          text: text,
          isUser: false,
          routeQuery: routeQuery,
          bookingDestination: bookingDestination,
        );

    final places =
        await MapService.searchPlaces(query, restrictToPhilippines: false);
    if (places.isEmpty) {
      return reply(
          'I could not find "$query". Try a more specific place name.');
    }
    final place = places.first;
    final destination = await MapService.getPlaceLatLng(place.placeId);
    if (destination == null) {
      return reply(
          'I found ${place.mainText}, but its location is unavailable.');
    }
    final origin = await MapService.getCurrentLocation();
    if (origin == null) {
      return reply('I found ${place.mainText}. Enable location access so I can '
          'find routes from where you are.');
    }
    final routes = await MapService.fetchRoutes(origin, destination,
        destinationPlaceId:
            place.placeId.startsWith('coord:') ? null : place.placeId);
    if (routes.isEmpty) {
      return reply('I found ${place.mainText}, but no road route is available '
          'right now. Check your connection or try another destination.');
    }
    final lines = <String>[
      '${routes.length} road route${routes.length == 1 ? '' : 's'} to '
          '${place.mainText} from your location:',
      for (var i = 0; i < routes.length; i++)
        '${i == 0 ? 'Suggested' : 'Route ${i + 1}'}: '
            '${routes[i].etaMinutes} min, '
            '${routes[i].distanceKm.toStringAsFixed(1)} km'
            '${routes[i].summary.isEmpty ? '' : ' via ${routes[i].summary}'}',
      'View the routes on the map to compare them.',
    ];
    return reply(
      lines.join('\n'),
      routeQuery: place.fullText,
      bookingDestination:
          BookingDestination(point: destination, name: place.mainText),
    );
  }

  Future<void> _toggleMic() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Microphone not available.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) setState(() => _ctrl.text = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  void _onSpeechDone() {
    if (!mounted) return;
    setState(() => _isListening = false);
    if (_ctrl.text.trim().isNotEmpty) _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _fmt(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Future<void> _showSources(FaqEntry faq) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Answer sources',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(faq.question),
              const SizedBox(height: 10),
              Text(
                  'Reviewed ${faq.reviewedAt}. External FAQ topics and guidance '
                  'are adapted to TodaGo. Other providers\' policies apply to '
                  'their own services.'),
              const SizedBox(height: 12),
              for (final reference in FaqService.referencesFor(faq))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reference.title),
                  subtitle: Text(
                      '${reference.author} (${reference.dateLabel})\n'
                      '${reference.usage == 'methodology' ? 'Methodology reference' : 'Adaptation topic'}: ${reference.topic}'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    var opened = false;
                    try {
                      opened = await launchUrl(Uri.parse(reference.url),
                          mode: LaunchMode.externalApplication);
                    } catch (_) {
                      // Offer the exact link if the device has no URL handler.
                    }
                    if (!opened && sheetContext.mounted) {
                      await showDialog<void>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Open source link'),
                          content: SelectableText(reference.url),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Close')),
                          ],
                        ),
                      );
                    }
                  },
                ),
              TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildMessages()),
        if (_showChips) _buildChips(),
        _buildInput(),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.backgroundDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFFFD166)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.question_answer_rounded,
                  color: AppColors.backgroundDark, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text('TodaGo Chatbot',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('FAQ',
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ]),
                    ),
                  ]),
                  Text(
                    'FAQs and directions',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _messages.length,
        itemBuilder: (_, i) => _buildBubble(_messages[i]),
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    if (msg.isTyping) return _buildTyping();
    final isUser = msg.isUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 56 : 0,
        right: isUser ? 0 : 56,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.question_answer_rounded,
                      color: AppColors.backgroundDark, size: 16),
                ),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.backgroundDark : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.text,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color:
                              isUser ? Colors.white : const Color(0xFF1A1A2E),
                          height: 1.45,
                        ),
                      ),
                      if (msg.faq != null) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: () => _showSources(msg.faq!),
                          icon: const Icon(Icons.menu_book_outlined, size: 16),
                          label: const Text('Sources'),
                        ),
                      ],
                      if (msg.routeQuery != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveMapScreen(
                                  initialDestinationQuery: msg.routeQuery),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('View routes on map'),
                        ),
                      ],
                      if (msg.bookingDestination != null) ...[
                        const SizedBox(height: 8),
                        BookDestinationButton(
                            destination: msg.bookingDestination!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 36,
              right: isUser ? 4 : 0,
            ),
            child: Text(
              _fmt(msg.time),
              style:
                  GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 56),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.question_answer_rounded,
              color: AppColors.backgroundDark, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final offsets = [0.0, 0.33, 0.66];
              return AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final v = ((_pulse.value + offsets[i]) % 1.0);
                  return Container(
                    width: 7,
                    height: 7,
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3 + 0.7 * v),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildChips() {
    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Quick FAQs',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _send(_chips[i]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(_chips[i],
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.backgroundDark)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Listening...'
                            : 'Ask a TodaGo FAQ...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _isListening
                              ? Colors.red.withOpacity(0.6)
                              : Colors.black38,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleMic,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 8),
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _isListening
                                ? Colors.red
                                    .withOpacity(0.8 + 0.2 * _pulse.value)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: _isListening ? Colors.white : Colors.black45,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _sending
                      ? AppColors.primary.withOpacity(0.5)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: _sending
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.backgroundDark,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: AppColors.backgroundDark, size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
