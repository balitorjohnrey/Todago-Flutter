import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todago/data/faq_dataset.g.dart';
import 'package:todago/faq_service.dart';
import 'package:todago/location_query.dart';

void main() {
  test(
      'all supported questions and aliases retrieve their own role-aware answer',
      () {
    for (final entry in FaqService.entries) {
      expect(entry.sources, isNotEmpty);
      expect(entry.reviewedAt, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      for (final role in entry.roles) {
        for (final query in [entry.question, ...entry.aliases]) {
          expect(FaqService.match(query, role)?.id, entry.id,
              reason: '$role: $query');
        }
      }
    }
    expect(FaqService.entries, hasLength(100));
  });

  test('each answer has accessible online source metadata and an APA citation',
      () {
    for (final entry in FaqService.entries) {
      final references = FaqService.referencesFor(entry);
      expect(references, isNotEmpty, reason: entry.id);
      for (final source in references) {
        expect(Uri.parse(source.url).scheme, 'https');
        expect(source.apaCitation, contains(source.url));
        expect(source.apaCitation, contains(source.dateLabel));
        expect(source.topic, isNotEmpty);
      }
    }
  });

  test(
      'bundled contents exactly match the canonical dataset in a combined checkout',
      () {
    final canonical = File('../todago_backend/src/data/faqs.json');
    if (canonical.existsSync()) {
      expect(
          jsonDecode(faqDatasetJson), jsonDecode(canonical.readAsStringSync()));
    }
    expect(FaqService.provenance, contains('source code'));
  });

  test('quick questions include provenance and respect the viewer role', () {
    for (final role in ['passenger', 'driver', 'guest']) {
      final questions = FaqService.quickQuestions(role);
      expect(questions, hasLength(7));
      expect(questions.map((entry) => entry.id), contains('faq_sources'));
      expect(questions.every((entry) => entry.roles.contains(role)), isTrue);
    }
    expect(FaqService.normalizeRole(' Commuter '), 'passenger');
    expect(FaqService.normalizeRole('DRIVER'), 'driver');
    expect(FaqService.normalizeRole('operator'), 'guest');
    expect(FaqService.match('How do I request a driver cash-out?', 'passenger'),
        isNull);
  });

  test(
      'specific topics and local-language questions avoid broad keyword matches',
      () {
    const examples = [
      ['passenger', 'please cancel my ride', 'cancel_trip'],
      ['passenger', 'How much is my fare', 'fares'],
      ['passenger', 'my top-up is not received', 'missing_top_up'],
      ['passenger', 'add money using gcash', 'wallet_top_up'],
      ['passenger', 'Where can I find my past trips?', 'passenger_history'],
      ['passenger', 'my driver location is stuck', 'track_driver'],
      ['passenger', 'Can I use the student fare?', 'discounted_fares'],
      ['passenger', 'Paano mag book ng ride?', 'book_ride'],
      ['guest', 'Pila ang plete?', 'fares'],
      ['driver', 'Unsaon pag online?', 'driver_online'],
      ['driver', 'how can I collect payment now', 'complete_trip'],
      ['driver', 'how can I rate a passenger', 'rate_passenger'],
      ['driver', 'I am not receiving ride requests', 'no_requests'],
      ['driver', 'withdraw my earnings', 'driver_cash_out'],
      ['guest', 'Where is FAQ data from?', 'faq_sources'],
      ['guest', 'Asa gikan ang data?', 'faq_sources'],
    ];
    for (final example in examples) {
      expect(FaqService.match(example[1], example[0])?.id, example[2],
          reason: example[1]);
    }
  });

  test('ambiguous, partial-word, and unrelated queries ask for clarification',
      () {
    for (final query in [
      '',
      'driver',
      'ride',
      'accurate',
      'corporate',
      'climate',
      'write a poem',
      'book cancel',
      'tell me my exact current balance'
    ]) {
      expect(FaqService.match(query, 'passenger'), isNull, reason: query);
    }
    expect(
        FaqService.fallbackAnswer('driver'), contains('one specific question'));
  });

  test('expanded topics distinguish a specific issue from general guidance',
      () {
    const examples = [
      ['passenger', 'show my wallet transactions', 'wallet_history'],
      ['passenger', 'my top up money is missing', 'missing_top_up'],
      ['passenger', 'change my rating', 'ratings_once'],
      ['passenger', 'how can i split the group fare', 'shared_fare'],
      ['passenger', 'add a landmark for pickup', 'booking_notes'],
      [
        'passenger',
        'my destination search has no results',
        'destination_search'
      ],
      ['passenger', 'no drivers online near me', 'no_drivers_passenger'],
      ['passenger', 'why am i being charged twice', 'duplicate_charge'],
      ['passenger', 'i already pressed done', 'topup_done'],
      ['driver', 'cashout is pending', 'cashout_status'],
      ['driver', 'why can i not cancel my cash out', 'cashout_cancel'],
      ['driver', 'the passenger never appeared', 'driver_no_show'],
      ['driver', 'i want to stop requests for a break', 'driver_stop_requests'],
      ['passenger', 'can i change payment method', 'payment_change'],
      ['passenger', 'i forgot to leave a rating', 'rate_later'],
      ['passenger', 'my payment is not confirmed', 'payment_pending'],
      ['passenger', 'can i reuse the same qr again', 'qr_reuse'],
      ['passenger', 'how do i report the wrong vehicle', 'wrong_vehicle'],
      ['passenger', 'my verification camera failed', 'identity_retry'],
      ['guest', 'how do i register a passenger account', 'register_passenger'],
    ];
    for (final example in examples) {
      expect(FaqService.match(example[1], example[0])?.id, example[2],
          reason: example[1]);
    }
  });

  test('unmatched FAQ terms do not become standalone place searches', () {
    for (final query in [
      'wallet balance',
      'refund',
      'dataset source',
      'gcash topup pending',
      'Paano mag refund'
    ]) {
      expect(looksLikeStandalonePlace(query), isFalse, reason: query);
    }
    expect(looksLikeStandalonePlace('Gaisano Mall'), isTrue);
    expect(
        locationQueryFromMessage('directions to Gaisano Mall'), 'Gaisano Mall');
  });

  test(
      'explicit place queries require a specific FAQ phrase to override directions',
      () {
    expect(
        FaqService.match('Where is Maya Hotel?', 'passenger',
            minKeywordWords: 2),
        isNull);
    expect(
        FaqService.match('Where can I find my past trips?', 'passenger',
                minKeywordWords: 2)
            ?.id,
        'passenger_history');
  });
}
