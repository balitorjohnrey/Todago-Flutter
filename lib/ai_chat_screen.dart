import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'app_theme.dart';

// ── Data models ───────────────────────────────────────────────────────────────
class _Msg {
  final String id;
  String text;
  final bool isUser;
  List<_NavAction> actions;
  bool isTyping;
  final DateTime time;

  _Msg({
    required this.id,
    required this.text,
    required this.isUser,
    this.actions = const [],
    this.isTyping = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class _NavAction {
  final String label;
  final String cmd;
  _NavAction(this.label, this.cmd);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AIChatScreen extends StatefulWidget {
  /// 'passenger' or 'driver'
  final String userType;
  final String userName;

  /// Called when the AI suggests navigation and the user taps the action button.
  /// Commands: 'book_ride' | 'tab_0' | 'tab_1' | 'tab_2' | 'tab_3' | 'past_trips'
  final void Function(String cmd)? onNavigate;

  const AIChatScreen({
    super.key,
    required this.userType,
    required this.userName,
    this.onNavigate,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  static const _storage      = FlutterSecureStorage();
  static const _backendBase  =
      'https://todago-backend-production.up.railway.app/api';

  // ── State ──────────────────────────────────────────────────────────────────
  final List<_Msg> _messages = [];
  final List<Map<String, dynamic>> _history = [];
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController      _scroll = ScrollController();
  final FocusNode             _focus  = FocusNode();

  bool _sending   = false;
  bool _showChips = true;

  // ── Voice ──────────────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechReady  = false;
  bool _isListening  = false;
  late AnimationController _micPulse;

  // ── Quick suggestion chips ─────────────────────────────────────────────────
  List<String> get _chips => widget.userType == 'passenger'
      ? [
          'How do I book a ride?',
          'Where is my driver?',
          'How do I rate my driver?',
          'How to top up my wallet?',
          'View my past trips',
          'How does fare pricing work?',
          'I have a problem with my trip',
        ]
      : [
          'How do I go online?',
          'How do earnings work?',
          'What is the commission rate?',
          'How to accept a ride?',
          'Why is my rating low?',
          'I have an issue with a trip',
          'How to complete a trip?',
        ];

  // ── System prompt (sent to backend, never exposed to client) ──────────────
  String get _systemPrompt => '''
You are TodaGo AI Support — the friendly, intelligent assistant built directly into the TodaGo tricycle-hailing app for the Davao Region, Philippines.

You are currently talking to a ${widget.userType.toUpperCase()} named ${widget.userName}.

━━━ ABOUT TODAGO ━━━
TodaGo is a tricycle-hailing app (like Grab, but for tricycles/trisikads) serving the Davao Region. Passengers book rides; drivers earn money by accepting and completing trips.

━━━ ${widget.userType == 'passenger' ? 'PASSENGER' : 'DRIVER'} FEATURES ━━━
${widget.userType == 'passenger' ? '''
HOME TAB:
• "Book Now" button opens the destination picker map
• Voice booking: tap the mic icon, say "Take me to [place]" — AI finds it automatically
• "Schedule Reservation" for future bookings

BOOKING FLOW:
1. Tap Book Now → Pick or speak your destination
2. Confirm the route (ETA + distance + estimated fare shown)
3. Choose service type: Solo (private) or Shared
4. Select payment: Cash, GCash, Maya, or TodaGo Wallet
5. A nearby driver is matched and notified
6. Wait screen shows driver details and live map
7. Track your driver in real-time as they navigate to you
8. Arrive at destination → driver completes trip
9. Rating screen appears → rate 1–5 stars + quick tags + optional comment

BOOKINGS TAB:
• Upcoming tab: active/scheduled trips with Track button
• Past tab: completed/cancelled trips with Rate button (if not yet rated)
• Pull down to refresh

WALLET TAB:
• View TodaGo Wallet balance
• Top up via GCash or Maya
• View full transaction history (filter: All / Top-up / Trips)
• Linked accounts management

PROFILE TAB:
• View name, email, phone
• See total trips completed
• Wallet balance snapshot
• Logout

FARES:
• Base: ₱15 minimum
• Rate: ~₱5 per km
• All fares shown before booking confirmation
• Solo = private ride; Shared = shared with others (cheaper)
''' : '''
DASHBOARD:
• Big circle button = GO ONLINE / OFFLINE toggle
• Stats bar shows today's earnings and total trips + rating
• Driver info card at bottom shows name, TODA body number, avg rating

GOING ONLINE:
• Tap the big yellow/green circle button
• Status changes to ONLINE — green pulsing animation
• App now polls for incoming ride requests every 4 seconds

ACCEPTING RIDES:
• A popup appears showing: passenger name, pickup location, destination, fare, service type
• Tap ACCEPT to take the ride, DECLINE to skip
• After accepting: navigate to pickup screen opens with map

TRIP FLOW:
1. Navigate to Pickup → Follow blue road route on map → tap "Confirm Arrival"
2. Active Trip screen → tap "Complete Trip" when passenger arrives at destination
3. Earnings shown: gross fare minus ₱5 flat commission = your payout

EARNINGS:
• Commission: flat ₱5 per completed ride
• Example: ₱25 fare → ₱5 commission → ₱20 to driver

RATINGS:
• Passengers rate you 1–5 stars after each trip
• Your avg_rating updates permanently in the system
• Shown on your dashboard card
• Improving rating: be on time, be friendly, keep vehicle clean
'''}

━━━ NAVIGATION COMMANDS ━━━
You can guide the user to specific app screens. Include EXACTLY ONE command at the very END of your message when navigation would genuinely help. Use this exact format:

[ACTION:book_ride|Book a Ride Now]
[ACTION:tab_0|Go to Home]
[ACTION:tab_1|View My Bookings]
[ACTION:tab_2|Open My Wallet]
[ACTION:tab_3|View My Profile]
[ACTION:past_trips|See Past Trips]

Rules:
• Only ONE per message
• Only when it genuinely helps navigation
• The [ACTION:...] will be hidden from display and shown as a button instead

━━━ RESPONSE RULES ━━━
• Be friendly, concise — max 120 words
• Simple language; Filipino/English mix is natural ("Sige!", "Para sa inyo")
• If asked about something outside TodaGo, gently redirect
• Never ask for passwords or sensitive info
• Keep responses focused and helpful
''';

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _addGreeting());
  }

  void _addGreeting() {
    final greeting = widget.userType == 'passenger'
        ? 'Hi ${widget.userName.split(' ').first}! 👋 I\'m your TodaGo AI assistant. I can help you book rides, check your wallet, view trip history, and answer any questions about the app.\n\nWhat can I help you with today?'
        : 'Hi ${widget.userName.split(' ').first}! 👋 I\'m your TodaGo Driver AI assistant. I can help you with going online, understanding your earnings, improving your rating, and any questions about the driver app.\n\nWhat do you need help with?';
    setState(() {
      _messages.add(_Msg(id: 'greeting', text: greeting, isUser: false));
    });
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') _onSpeechDone();
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _micPulse.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Get auth token (passenger or driver) ───────────────────────────────────
  Future<String?> _getToken() async {
    if (widget.userType == 'driver') {
      return await _storage.read(key: 'driver_auth_token');
    }
    return await _storage.read(key: 'auth_token');
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> _send([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    _focus.unfocus();
    setState(() { _sending = true; _showChips = false; });

    final userMsg = _Msg(
        id: UniqueKey().toString(), text: text, isUser: true);
    setState(() => _messages.add(userMsg));
    _history.add({'role': 'user', 'content': text});
    _scrollToBottom();

    // Add typing indicator
    final typingId = UniqueKey().toString();
    setState(() => _messages.add(
        _Msg(id: typingId, text: '', isUser: false, isTyping: true)));
    _scrollToBottom();

    try {
      final aiText = await _callAI();
      if (!mounted) return;
      final parsed = _parseActions(aiText);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == typingId);
        if (idx != -1) {
          _messages[idx] = _Msg(
            id: typingId,
            text: parsed.text,
            isUser: false,
            actions: parsed.actions,
          );
        }
      });
      _history.add({'role': 'assistant', 'content': parsed.text});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == typingId);
        if (idx != -1) {
          _messages[idx] = _Msg(
            id: typingId,
            text: 'Sorry, something went wrong. Please try again.',
            isUser: false,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    _scrollToBottom();
  }

  // ── AI call → goes through YOUR backend (API key stays on server) ──────────
  Future<String> _callAI() async {
    final token = await _getToken();

    final response = await http.post(
      Uri.parse('$_backendBase/ai/chat'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'system':     _systemPrompt,
        'messages':   _history,
        'max_tokens': 400,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Anthropic response format: { content: [ { type: 'text', text: '...' } ] }
      return (data['content'] as List?)
              ?.firstWhere(
                (c) => c['type'] == 'text',
                orElse: () => {'text': 'I could not generate a response.'},
              )['text']
              ?.toString()
              .trim() ??
          'I could not generate a response.';
    }

    // Try to parse error message from backend
    try {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Status ${response.statusCode}');
    } catch (_) {
      throw Exception('Server returned status ${response.statusCode}');
    }
  }

  // ── Parse [ACTION:cmd|Label] from AI response ──────────────────────────────
  ({String text, List<_NavAction> actions}) _parseActions(String raw) {
    final actions = <_NavAction>[];
    final pattern = RegExp(r'\[ACTION:([^\|]+)\|([^\]]+)\]');
    final clean   = raw.replaceAllMapped(pattern, (m) {
      actions.add(_NavAction(m.group(2)!.trim(), m.group(1)!.trim()));
      return '';
    }).trim();
    return (text: clean, actions: actions);
  }

  // ── Execute navigation action ──────────────────────────────────────────────
  void _executeAction(_NavAction action) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onNavigate?.call(action.cmd);
  }

  // ── Voice ──────────────────────────────────────────────────────────────────
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
      onResult: (r) {
        if (mounted) setState(() => _ctrl.text = r.recognizedWords);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor:  const Duration(seconds: 3),
      localeId:  'en_US',
      cancelOnError: true,
    );
  }

  void _onSpeechDone() {
    if (!mounted) return;
    setState(() => _isListening = false);
    if (_ctrl.text.trim().isNotEmpty) _send();
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _buildMessages()),
        if (_showChips && _messages.length <= 1) _buildChips(),
        _buildInput(),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
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
                width: 38, height: 38,
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
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFFFD166)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppColors.backgroundDark, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text('TodaGo AI Support',
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
                        width: 5, height: 5,
                        decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text('Online',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                    ]),
                  ),
                ]),
                Text(
                  widget.userType == 'passenger'
                      ? 'Passenger Support · Always available'
                      : 'Driver Support · Always available',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.white54),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Messages list ───────────────────────────────────────────────────────────
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
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.backgroundDark, size: 16),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.backgroundDark : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: isUser
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 36,
              right: isUser ? 4 : 0,
            ),
            child: Text(
              _fmt(msg.time),
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textHint),
            ),
          ),

          // Navigation action buttons
          if (msg.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 36),
              child: Wrap(
                spacing: 8, runSpacing: 6,
                children: msg.actions
                    .map((a) => GestureDetector(
                          onTap: () => _executeAction(a),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              const Icon(Icons.arrow_forward_rounded,
                                  color: AppColors.backgroundDark, size: 14),
                              const SizedBox(width: 6),
                              Text(a.label,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.backgroundDark)),
                            ]),
                          ),
                        ))
                    .toList(),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  // ── Typing indicator ───────────────────────────────────────────────────────
  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 56),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          width: 28, height: 28,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.support_agent_rounded,
              color: AppColors.backgroundDark, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomLeft:  Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => AnimatedBuilder(
                animation: _micPulse,
                builder: (_, __) {
                  final offsets = [0.0, 0.33, 0.66];
                  final v = ((_micPulse.value + offsets[i]) % 1.0);
                  return Container(
                    width: 7, height: 7,
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3 + 0.7 * v),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Quick chips ────────────────────────────────────────────────────────────
  Widget _buildChips() {
    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Quick questions',
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
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

  // ── Input bar ─────────────────────────────────────── FIXED: white + black ──
  Widget _buildInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            // ── Text field — plain white, black text ──────────────────────
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode:  _focus,
                      maxLines:   null,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.poppins(
                        fontSize:  14,
                        color:     Colors.black,      // ← black text
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Listening...'
                            : 'Ask me anything...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _isListening
                              ? Colors.red.withOpacity(0.6)
                              : Colors.black38,       // ← visible placeholder
                        ),
                        border:        InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled:     true,
                        fillColor:  Colors.white,     // ← white background
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  // Mic
                  GestureDetector(
                    onTap: _toggleMic,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 8),
                      child: AnimatedBuilder(
                        animation: _micPulse,
                        builder: (_, __) => Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: _isListening
                                ? Colors.red
                                    .withOpacity(0.8 + 0.2 * _micPulse.value)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: _isListening
                                ? Colors.white
                                : Colors.black45,     // ← visible on white
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
            // Send button
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46, height: 46,
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
                          )
                        ],
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.backgroundDark))
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