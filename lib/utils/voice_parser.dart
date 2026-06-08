class ExtractedPair {
  final int position;
  final double? mark;
  ExtractedPair({required this.position, this.mark});
}

const Map<String, int> _swahiliNumbers = {
  'moja': 1, 'kwanza': 1,
  'mbili': 2, 'pili': 2,
  'tatu': 3, 'nne': 4,
  'tano': 5, 'sita': 6,
  'saba': 7, 'nane': 8,
  'tisa': 9, 'kumi': 10,
  'ishirini': 20, 'thelathini': 30,
  'arobaini': 40, 'hamsini': 50,
  'sitini': 60, 'sabini': 70,
  'themanini': 80, 'tisini': 90,
  'mia': 100,
};

const Map<String, int> _englishNumbers = {
  'one': 1, 'first': 1,
  'two': 2, 'second': 2,
  'three': 3, 'third': 3,
  'four': 4, 'fourth': 4,
  'five': 5, 'fifth': 5,
  'six': 6, 'sixth': 6,
  'seven': 7, 'seventh': 7,
  'eight': 8, 'eighth': 8,
  'nine': 9, 'ninth': 9,
  'ten': 10, 'tenth': 10,
  'eleven': 11, 'twelve': 12,
  'twelfth': 12, 'thirteen': 13,
  'fourteen': 14, 'fifteen': 15,
  'sixteen': 16, 'seventeen': 17,
  'eighteen': 18, 'nineteen': 19,
  'twenty': 20, 'thirty': 30,
  'forty': 40, 'fifty': 50,
  'sixty': 60, 'seventy': 70,
  'eighty': 80, 'ninety': 90,
  'hundred': 100,
};

double? _parseSpokenNumber(String text) {
  final clean = text.toLowerCase().trim();
  if (clean.isEmpty) return null;
  final parsed = double.tryParse(clean);
  if (parsed != null) return parsed;
  final words = clean.split(RegExp(r'[\s-]+'));
  double total = 0;
  double temp = 0;
  for (final rawWord in words) {
    final word = rawWord.replaceAll(RegExp(r'[.,:;()?]'), '').trim();
    if (word.isEmpty || word == 'na' || word == 'and') continue;
    final numVal = double.tryParse(word);
    if (numVal != null) { temp += numVal; continue; }
    final sw = _swahiliNumbers[word];
    final en = _englishNumbers[word];
    final n = sw ?? en;
    if (n != null) {
      if (n == 100) {
        if (temp == 0) temp = 1;
        total += temp * 100;
        temp = 0;
      } else {
        temp += n;
      }
    }
  }
  total += temp;
  return total > 0 ? total : null;
}

List<ExtractedPair> ruleBasedVoiceParser(String text) {
  if (text.isEmpty) return [];
  final segments = text.split(RegExp(r'[,.]|\b(?:and|na|then|kisha)\b'));
  final pairs = <ExtractedPair>[];
  final markTriggers = [
    'amepata', 'anapata', 'ana', 'ni', 'alipata', 'kapata', 'amefaulu',
    'has', 'got', 'scored', 'gets', 'received', 'is', 'points',
  ];
  for (final rawSegment in segments) {
    final segment = rawSegment.trim();
    if (segment.isEmpty) continue;
    final lowerSegment = segment.toLowerCase();
    int? position;
    int posIndex = -1;
    int posLength = 0;
    final digitMatch = RegExp(r'\b(?:number|namba|nambari|student)\s*(\d+)\b', caseSensitive: false).firstMatch(segment);
    if (digitMatch != null) {
      position = int.tryParse(digitMatch.group(1)!);
      posIndex = segment.toLowerCase().indexOf(digitMatch.group(0)!.toLowerCase());
      posLength = digitMatch.group(0)!.length;
    } else {
      final positionPrefixes = [
        'namba', 'nambari', 'wa kwanza', 'wa pili', 'wa tatu', 'wa nne', 'wa tano',
        'number', 'student', 'position', 'the first', 'first', 'second', 'third', 'fourth', 'fifth',
        'group', 'kundi', 'team', 'timu', 'group ya', 'kundi la',
      ];
      for (final prefix in positionPrefixes) {
        final idx = lowerSegment.indexOf(prefix);
        if (idx != -1) {
          final afterPrefix = segment.substring(idx + prefix.length).trim();
          final wordsAfter = afterPrefix.split(RegExp(r'\s+'));
          if (wordsAfter.isNotEmpty) {
            double? parsedVal = _parseSpokenNumber(wordsAfter[0]);
            int wordsTaken = 1;
            if (wordsAfter.length >= 3 && (wordsAfter[1].toLowerCase() == 'na' || wordsAfter[1].toLowerCase() == 'and')) {
              final compound = _parseSpokenNumber(wordsAfter.sublist(0, 3).join(' '));
              if (compound != null) { parsedVal = compound; wordsTaken = 3; }
            } else if (wordsAfter.length >= 2) {
              final twoWords = _parseSpokenNumber(wordsAfter.sublist(0, 2).join(' '));
              if (twoWords != null) { parsedVal = twoWords; wordsTaken = 2; }
            }
            if (parsedVal != null) {
              position = parsedVal.toInt();
              posIndex = idx;
              posLength = prefix.length + wordsAfter.take(wordsTaken).join(' ').length + 1;
              break;
            }
          }
        }
      }
    }
    if (position == null || posIndex == -1) continue;
    final textAfterPos = segment.substring(posIndex + posLength).trim();
    double? mark;
    bool markFound = false;
    for (final trigger in markTriggers) {
      final trigIdx = textAfterPos.toLowerCase().indexOf(trigger);
      if (trigIdx != -1) {
        final textAfterTrigger = textAfterPos.substring(trigIdx + trigger.length).trim();
        final wordsAfter = textAfterTrigger.split(RegExp(r'\s+'));
        if (wordsAfter.isNotEmpty) {
          final m = _parseSpokenNumber(wordsAfter[0]);
          if (m != null) { mark = m; markFound = true; break; }
        }
      }
    }
    if (!markFound) {
      final digitsAfter = RegExp(r'\b(\d+)\b').firstMatch(textAfterPos);
      if (digitsAfter != null) {
        mark = double.tryParse(digitsAfter.group(1)!);
      } else {
        final wordsAfter = textAfterPos.split(RegExp(r'\s+'));
        for (int i = 0; i < wordsAfter.length; i++) {
          double? p = _parseSpokenNumber(wordsAfter[i]);
          if (p != null) {
            if (i + 2 < wordsAfter.length && (wordsAfter[i + 1].toLowerCase() == 'na' || wordsAfter[i + 1].toLowerCase() == 'and')) {
              final cp = _parseSpokenNumber(wordsAfter.sublist(i, i + 3).join(' '));
              if (cp != null) p = cp;
            }
            mark = p;
            break;
          }
        }
      }
    }
    pairs.add(ExtractedPair(position: position, mark: mark));
  }
  final uniqueMap = <int, ExtractedPair>{};
  for (final pair in pairs) {
    uniqueMap[pair.position] = pair;
  }
  return uniqueMap.values.take(5).toList();
}
