import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_theme.dart';
import 'map_service.dart';
import 'service_selection_screen.dart';
import 'smart_ride_service.dart';

class _Msg {
  final String id;
  final String text;
  final bool isUser;
  final bool isTyping;
  final DateTime time;
  final RideIntent? rideIntent;

  _Msg({
    required this.id,
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.rideIntent,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class _FaqItem {
  final String question;
  final String answer;
  final List<String> keywords;
  final Set<String> roles;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.keywords,
    required this.roles,
  });
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
  bool _preparingRide = false;
  bool _showChips = true;
  late AnimationController _pulse;

  static const List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'How do I book a ride?',
      answer:
          'Tap Book Now, choose your destination, confirm the route and fare, choose a service type, then select a driver. You can track the trip after the request is accepted.',
      keywords: ['book', 'ride', 'request', 'destination', 'driver'],
      roles: {'passenger'},
    ),
    _FaqItem(
      question: 'How do I cancel a trip?',
      answer:
          'Open the active trip or waiting screen and tap Cancel Trip. If a driver was already assigned, TodaGo notifies the driver and releases them for other rides.',
      keywords: ['cancel', 'cancellation', 'trip', 'ride'],
      roles: {'passenger'},
    ),
    _FaqItem(
      question: 'How do fares work?',
      answer:
          'TodaGo shows the estimated fare before confirmation. The fare is based on the route distance, service type, and minimum base fare. Cash is currently the default payment flow in the app.',
      keywords: ['fare', 'price', 'pricing', 'cost', 'payment'],
      roles: {'passenger', 'driver'},
    ),
    _FaqItem(
      question: 'How do I rate my driver?',
      answer:
          'After a completed trip, the rating screen appears. Choose 1 to 5 stars, select quick feedback tags, and submit. You can also rate completed trips from Past Trips if you skipped it.',
      keywords: ['rate', 'rating', 'stars', 'feedback', 'review'],
      roles: {'passenger'},
    ),
    _FaqItem(
      question: 'Where can I see my past trips?',
      answer:
          'Go to Bookings, then open the Past tab. Pull down to refresh if your latest completed or cancelled trip is not visible yet.',
      keywords: ['past', 'history', 'bookings', 'completed', 'cancelled'],
      roles: {'passenger'},
    ),
    _FaqItem(
      question: 'How do I upload a profile picture?',
      answer:
          'Open Profile and tap your avatar or Upload Photo. Choose an image from your gallery. The app saves it locally so your profile looks personal on this device.',
      keywords: ['profile', 'picture', 'photo', 'avatar', 'upload'],
      roles: {'passenger', 'driver'},
    ),
    _FaqItem(
      question: 'How do I go online as a driver?',
      answer:
          'On the driver dashboard, tap the large GO ONLINE button. When it turns green, you are available and TodaGo checks for incoming ride requests.',
      keywords: ['online', 'offline', 'available', 'driver', 'go online'],
      roles: {'driver'},
    ),
    _FaqItem(
      question: 'How do I accept a ride request?',
      answer:
          'When a ride request popup appears, review the pickup, destination, fare, and service type. Tap ACCEPT to take the ride or DECLINE if you cannot take it.',
      keywords: ['accept', 'request', 'decline', 'popup', 'ride'],
      roles: {'driver'},
    ),
    _FaqItem(
      question: 'How do driver earnings work?',
      answer:
          'Driver earnings are shown after completing a trip. The payout summary uses the passenger fare for that completed ride.',
      keywords: ['earnings', 'income', 'payout', 'fare'],
      roles: {'driver'},
    ),
    _FaqItem(
      question: 'How do I complete a trip?',
      answer:
          'After pickup, follow the active trip screen. When the passenger reaches the destination, tap Complete Trip. The app then records the completed status and shows earnings.',
      keywords: ['complete', 'finish', 'end', 'trip', 'destination'],
      roles: {'driver'},
    ),
    _FaqItem(
      question: 'How can I improve my driver rating?',
      answer:
          'Arrive on time, confirm the passenger name, drive safely, keep the vehicle clean, and politely remind passengers they can rate the trip after completion.',
      keywords: ['improve', 'rating', 'low', 'stars', 'feedback'],
      roles: {'driver'},
    ),
    _FaqItem(
      question: 'What should I do if something goes wrong?',
      answer:
          'For app issues, check your internet connection, refresh the current screen, and try again. For trip safety or account problems, contact TodaGo support or your operator.',
      keywords: ['problem', 'issue', 'error', 'support', 'help', 'wrong'],
      roles: {'passenger', 'driver'},
    ),
  ];

  List<String> get _chips =>
      _roleFaqs.take(7).map((faq) => faq.question).toList();

  List<_FaqItem> get _roleFaqs {
    final role = widget.userType.toLowerCase();
    return _faqs.where((faq) => faq.roles.contains(role)).toList();
  }

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
    final roleText = widget.userType == 'driver' ? 'driver' : 'passenger';
    setState(() {
      _messages.add(_Msg(
        id: 'greeting',
        text:
            'Hi $firstName! I am the TodaGo Chatbot. I answer TodaGo $roleText FAQs only. Choose a quick question or type a TodaGo question.',
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

    final rideIntent = widget.userType.toLowerCase() == 'passenger'
        ? await SmartRideService.parseRideIntent(text)
        : null;
    final isRideIntent = rideIntent?.isRideIntent == true;
    final response = isRideIntent
        ? (rideIntent!.reply.isNotEmpty
            ? rideIntent.reply
            : 'I can help start that ride. Please confirm before I continue.')
        : _answerFaq(text);

    setState(() {
      final idx = _messages.lastIndexWhere((msg) => msg.isTyping);
      if (idx != -1) {
        _messages[idx] = _Msg(
          id: UniqueKey().toString(),
          text: response,
          isUser: false,
          rideIntent:
              rideIntent?.canContinueBooking == true ? rideIntent : null,
        );
      }
      _sending = false;
    });
    _scrollToBottom();
  }

  String _answerFaq(String question) {
    final normalized = _normalize(question);
    if (normalized.isEmpty) return _fallbackAnswer();

    _FaqItem? best;
    var bestScore = 0;
    for (final faq in _roleFaqs) {
      var score = 0;
      final faqQuestion = _normalize(faq.question);
      if (faqQuestion == normalized) score += 8;
      if (faqQuestion.contains(normalized) ||
          normalized.contains(faqQuestion)) {
        score += 4;
      }
      for (final keyword in faq.keywords) {
        final cleanKeyword = _normalize(keyword);
        if (normalized.contains(cleanKeyword)) score += 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = faq;
      }
    }

    if (best != null && bestScore >= 2) return best.answer;
    return _fallbackAnswer();
  }

  Future<void> _startSmartRide(RideIntent intent) async {
    if (_preparingRide) return;
    final destinationQuery = intent.destinationQuery.trim();
    if (destinationQuery.isEmpty) {
      _showSnack('Please tell me your destination first.', AppColors.error);
      return;
    }

    setState(() => _preparingRide = true);
    try {
      final pickup = await MapService.getCurrentLocation()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (!mounted) return;

      if (pickup == null) {
        _showSnack(
          'I could not get your current location yet.',
          AppColors.error,
        );
        return;
      }

      final suggestions = await MapService.searchPlaces(
        destinationQuery,
        locationBias: pickup,
      );
      if (!mounted) return;

      if (suggestions.isEmpty) {
        _showSnack(
          'I could not find "$destinationQuery". Try a more specific place.',
          AppColors.error,
        );
        return;
      }

      final place = suggestions.first;
      final destination = await MapService.getPlaceLatLng(place.placeId);
      if (!mounted) return;

      if (destination == null) {
        _showSnack(
          'I found the place, but could not get its map location.',
          AppColors.error,
        );
        return;
      }

      var pickupName = 'Your Location';
      try {
        pickupName = await MapService.reverseGeocode(pickup)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        pickupName = 'Your Location';
      }

      final route = await MapService.fetchRoute(pickup, destination);
      if (!mounted) return;

      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, __, ___) => ServiceSelectionScreen(
          pickupName: pickupName,
          destinationName:
              place.mainText.isNotEmpty ? place.mainText : destinationQuery,
          pickupLatLng: pickup,
          destinationLatLng: destination,
          etaMinutes: route?.etaMinutes,
          distanceKm: route?.distanceKm,
          initialServiceType: intent.selectedServiceType,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ));
    } finally {
      if (mounted) setState(() => _preparingRide = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _fallbackAnswer() {
    final topics = _roleFaqs.take(4).map((faq) => faq.question).join(', ');
    return 'I can only answer TodaGo FAQs. Try asking about: $topics.';
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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
                    Text('TodaGo Chatbot',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
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
                    'TodaGo FAQs only',
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
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
                      if (msg.rideIntent != null) ...[
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _preparingRide
                              ? null
                              : () => _startSmartRide(msg.rideIntent!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.55),
                            foregroundColor: AppColors.backgroundDark,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_preparingRide)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.backgroundDark,
                                  ),
                                )
                              else
                                const Icon(Icons.directions_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _preparingRide
                                    ? 'Preparing...'
                                    : 'Continue booking',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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
