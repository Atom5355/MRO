String normalizeSearchText(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> tokenizeSearchText(String text) {
  return normalizeSearchText(text)
      .replaceAll(RegExp(r'[^\w\s\d/\-.#]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
}

String normalizeSearchIdentifier(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

bool isSearchStopWord(String token) {
  return _searchStopWords.contains(token);
}

/// Normalize a word to handle singular/plural forms.
List<String> getPluralVariations(String word) {
  final normalizedWord = normalizeSearchText(word);
  final variations = <String>{normalizedWord};

  if (normalizedWord.isEmpty) {
    return variations.toList();
  }

  // If ends with 's', try removing it (plural -> singular)
  if (normalizedWord.endsWith('ies')) {
    variations.add(
      '${normalizedWord.substring(0, normalizedWord.length - 3)}y',
    );
  } else if (normalizedWord.endsWith('es')) {
    variations.add(normalizedWord.substring(0, normalizedWord.length - 2));
    variations.add(normalizedWord.substring(0, normalizedWord.length - 1));
  } else if (normalizedWord.endsWith('s') && normalizedWord.length > 2) {
    variations.add(normalizedWord.substring(0, normalizedWord.length - 1));
  }

  // If doesn't end with 's', try adding it (singular -> plural)
  if (!normalizedWord.endsWith('s')) {
    if (normalizedWord.endsWith('y') &&
        normalizedWord.length > 2 &&
        !_isVowel(normalizedWord[normalizedWord.length - 2])) {
      variations.add(
        '${normalizedWord.substring(0, normalizedWord.length - 1)}ies',
      );
    } else if (normalizedWord.endsWith('x') ||
        normalizedWord.endsWith('ch') ||
        normalizedWord.endsWith('sh')) {
      variations.add('${normalizedWord}es');
    } else {
      variations.add('${normalizedWord}s');
    }
  }

  return variations.toList();
}

bool _isVowel(String char) {
  return 'aeiou'.contains(char.toLowerCase());
}

const Set<String> _searchStopWords = {
  'a',
  'an',
  'and',
  'by',
  'for',
  'from',
  'i',
  'in',
  'inch',
  'looking',
  'made',
  'mfg',
  'need',
  'of',
  'on',
  'or',
  'the',
  'to',
  'want',
  'with',
};