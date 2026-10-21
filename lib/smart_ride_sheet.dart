import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_theme.dart';
import 'smart_ride_service.dart';

class SmartRideSheet extends StatefulWidget {
  const SmartRideSheet({super.key});

  @override
  State<SmartRideSheet> createState() => _SmartRideSheetState();
}

class _SmartRideSheetState extends State<SmartRideSheet> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _parsing = false;
  bool _speechReady = false;
  bool _isListening = false;
  String? _error;
  String _lastSpeechText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _finishListening();
        }
      },
    );
    if (mounted) setState(() => _speechReady = ready);
  }

  Future<void> _toggleListening() async {
    if (_parsing) return;
    if (!_speechReady) {
      setState(() => _error = 'Microphone is not available on this device.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      _finishListening();
      return;
    }

    setState(() {
      _isListening = true;
      _error = null;
      _lastSpeechText = '';
    });

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _lastSpeechText = result.recognizedWords.trim();
        _controller.text = _lastSpeechText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        if (result.finalResult) _finishListening();
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: true,
      ),
    );
  }

  void _finishListening() {
    if (!mounted || !_isListening) return;
    setState(() => _isListening = false);
    if (_lastSpeechText.isEmpty && _controller.text.trim().isEmpty) {
      setState(() => _error = 'Nothing heard. Please try again.');
    }
  }

  Future<void> _submit() async {
    final command = _controller.text.trim();
    if (command.isEmpty || _parsing) return;

    setState(() {
      _parsing = true;
      _error = null;
    });

    final intent = await SmartRideService.parseRideIntent(command);
    if (!mounted) return;

    if (intent == null || !intent.canContinueBooking) {
      setState(() {
        _parsing = false;
        _error = intent?.reply.isNotEmpty == true
            ? intent!.reply
            : 'Tell me where you want to go, like "Book me a ride to Gaisano".';
      });
      return;
    }

    Navigator.of(context).pop(intent);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight =
        (media.size.height - media.viewInsets.bottom - media.padding.top) * 0.9;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.backgroundDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Ride',
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.backgroundDark,
                              ),
                            ),
                            Text(
                              'Tell TodaGo where you want to go',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close Smart Ride',
                        onPressed: () => Navigator.of(context).pop(),
                        color: AppColors.backgroundDark,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.backgroundDark,
                              ),
                              decoration: InputDecoration(
                                hintText: _isListening
                                    ? 'Listening...'
                                    : 'Example: Book me a ride to Gaisano from my current location',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _isListening
                                      ? AppColors.error.withValues(alpha: 0.7)
                                      : AppColors.textHint,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  8,
                                  14,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 6, 8, 8),
                            child: GestureDetector(
                              onTap: _toggleListening,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? AppColors.error
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isListening
                                        ? AppColors.error
                                        : const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _isListening
                                      ? Colors.white
                                      : AppColors.backgroundDark,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                        _isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.keyboard_voice_rounded,
                        size: 14,
                        color:
                            _isListening ? AppColors.error : AppColors.textHint,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _isListening
                              ? 'Listening for your ride request'
                              : 'Tap the microphone to speak your request',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _isListening
                                ? AppColors.error
                                : AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _parsing ? null : _submit,
                        icon: _parsing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.directions_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          _parsing ? 'Understanding...' : 'Plan Smart Ride',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.backgroundDark,
                          disabledBackgroundColor:
                              AppColors.backgroundDark.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
