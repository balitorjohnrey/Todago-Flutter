/// Extracts a destination from a directions question without treating a
/// general TodaGo FAQ as a place search.
String? locationQueryFromMessage(String message) {
  final text = message.trim().replaceFirst(RegExp(r'[?.!]+$'), '').trim();
  if (text.isEmpty) return null;
  final patterns = [
    RegExp(
        r'^(?:how (?:do|can) i (?:get|go|travel|drive|ride) to|'
        r'where (?:is|can i find)|where\x27s|'
        r'(?:show me |find |give me )?(?:the )?(?:route|directions|way) to|'
        r'can you (?:show me|give me|find) (?:the )?(?:route|directions|way) to|'
        r'show me how to get to|'
        r'(?:navigate|take me|bring me|go|drive|ride|head) to|'
        r'how far is)\s+(.+)$',
        caseSensitive: false),
    RegExp(r'^(.+?)\s+(?:location|on the map)$', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final place = match.group(1)?.trim();
      if (place != null &&
          place.length >= 2 &&
          !RegExp(r'^(?:my |the )?(?:driver|ride|trip|booking|account|location)$',
                  caseSensitive: false)
              .hasMatch(place)) {
        return place;
      }
    }
  }
  return null;
}

bool looksLikeStandalonePlace(String message) {
  final text = message.trim();
  if (text.length < 3 || text.length > 80 || text.contains('?')) return false;
  final words = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length > 5) return false;
  const nonPlaces = {
    'i',
    'my',
    'you',
    'your',
    'how',
    'what',
    'why',
    'when',
    'who',
    'can',
    'please',
    'help',
    'hello',
    'hi',
    'thanks',
    'thank',
    'book',
    'cancel',
    'fare',
    'price',
    'driver',
    'trip',
    'payment',
    'rating',
    'support',
  };
  return !words.any(nonPlaces.contains);
}
