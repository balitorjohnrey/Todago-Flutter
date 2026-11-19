import 'dart:convert';

import 'data/faq_dataset.g.dart';

class FaqSource {
  final String path;
  final String locator;

  const FaqSource({required this.path, required this.locator});
}

class FaqOnlineReference {
  final String id;
  final String author;
  final String title;
  final String url;
  final String dateLabel;
  final String apaCitation;
  final String topic;
  final String usage;

  FaqOnlineReference.fromJson(
      Map<String, dynamic> source, Map<String, dynamic> reference)
      : id = source['id'] as String,
        author = source['author'] as String,
        title = source['title'] as String,
        url = source['url'] as String,
        dateLabel = source['dateLabel'] as String,
        apaCitation = source['apaCitation'] as String,
        topic = reference['topic'] as String,
        usage = reference['usage'] as String;
}

class FaqEntry {
  final String id;
  final String category;
  final String question;
  final String answer;
  final List<String> aliases;
  final List<String> keywords;
  final List<String> roles;
  final List<FaqSource> sources;
  final String reviewedAt;
  final List<Map<String, dynamic>> onlineReferences;
  final List<List<String>> intentGroups;

  FaqEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        category = json['category'] as String,
        question = json['question'] as String,
        answer = json['answer'] as String,
        aliases = List<String>.unmodifiable(json['aliases'] as List),
        keywords = List<String>.unmodifiable(json['keywords'] as List),
        roles = List<String>.unmodifiable(json['roles'] as List),
        sources = List<FaqSource>.unmodifiable((json['sources'] as List).map(
            (source) => FaqSource(
                path: source['path'] as String,
                locator: source['locator'] as String))),
        reviewedAt = json['reviewedAt'] as String,
        onlineReferences = List<Map<String, dynamic>>.unmodifiable(
            (json['onlineReferences'] as List)
                .map((item) => Map<String, dynamic>.unmodifiable(item as Map))),
        intentGroups = List<List<String>>.unmodifiable(
            (json['intentGroups'] as List? ?? [])
                .map((group) => List<String>.unmodifiable(group as List)));
}

/// Offline reference answers generated from the same JSON used by the API.
/// Keep matching behavior in sync with todago_backend/src/services/faq.js.
class FaqService {
  static final Map<String, dynamic> _dataset =
      jsonDecode(faqDatasetJson) as Map<String, dynamic>;
  static final List<FaqEntry> entries = List<FaqEntry>.unmodifiable(
      (_dataset['entries'] as List)
          .map((entry) => FaqEntry.fromJson(entry as Map<String, dynamic>)));
  static String get version => _dataset['version'] as String;
  static String get provenance => _dataset['provenance'] as String;
  static final Map<String, Map<String, dynamic>> _onlineSources = {
    for (final source in jsonDecode(faqOnlineSourcesJson) as List)
      source['id'] as String: Map<String, dynamic>.from(source as Map)
  };

  static List<FaqOnlineReference> referencesFor(FaqEntry entry) =>
      entry.onlineReferences
          .map((reference) => FaqOnlineReference.fromJson(
              _onlineSources[reference['sourceId']]!, reference))
          .toList();

  static String normalizeRole(String role) {
    final value = role.toLowerCase().trim();
    if (value == 'commuter') return 'passenger';
    return ['passenger', 'driver'].contains(value) ? value : 'guest';
  }

  static List<FaqEntry> forRole(String role) => entries
      .where((entry) => entry.roles.contains(normalizeRole(role)))
      .toList();

  static List<FaqEntry> quickQuestions(String role) {
    final ids =
        (_dataset['quickQuestions'] as Map)[normalizeRole(role)] as List;
    return ids
        .map((id) => entries.firstWhere((entry) => entry.id == id))
        .toList();
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp("['\u2019]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static FaqEntry? match(String message, String role,
      {int minKeywordWords = 1}) {
    final query = _normalize(message);
    if (query.isEmpty) return null;
    final candidates = forRole(role);
    for (final entry in candidates) {
      if ([entry.question, ...entry.aliases]
          .any((question) => _normalize(question) == query)) {
        return entry;
      }
    }
    if (entries.any((entry) => [entry.question, ...entry.aliases]
        .any((question) => _normalize(question) == query))) {
      return null;
    }

    FaqEntry? best;
    var bestScore = 0;
    var tied = false;
    for (final entry in candidates) {
      var score = 0;
      final phrases =
          entry.keywords.map(_normalize).where((p) => p.isNotEmpty).toSet();
      for (final phrase in phrases) {
        final words = phrase.split(' ').length;
        if (words >= minKeywordWords && ' $query '.contains(' $phrase ')) {
          score += words * 2;
        }
      }
      if (minKeywordWords == 1 && entry.intentGroups.isNotEmpty) {
        final groups = entry.intentGroups
            .map((group) => group
                .map(_normalize)
                .where((phrase) => ' $query '.contains(' $phrase '))
                .toList())
            .toList();
        if (groups.every((group) => group.isNotEmpty)) {
          score += 12;
          for (final group in groups) {
            score += group
                    .map((phrase) => phrase.split(' ').length)
                    .reduce((a, b) => a > b ? a : b) *
                2;
          }
        }
      }
      if (score > bestScore) {
        best = entry;
        bestScore = score;
        tied = false;
      } else if (score > 0 && score == bestScore) {
        tied = true;
      }
    }
    return bestScore >= 2 && !tied ? best : null;
  }

  static String fallbackAnswer(String role) {
    final topics =
        quickQuestions(role).take(4).map((entry) => entry.question).join(' ');
    return 'I could not confidently match that to a TodaGo FAQ. '
        'Please ask one specific question. Try: $topics';
  }
}
