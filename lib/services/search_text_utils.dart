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

/// Returns whether [phrase] occurs on alpha-numeric boundaries in [text].
///
/// Plain `contains` is unsafe for short industrial abbreviations: for example,
/// `brass` contains `ss`, `ball` contains `al`, and `timing` contains `ti`.
/// This helper still supports punctuation-heavy values such as `#50`, `3M`,
/// and `SEW-Eurodrive`, but does not treat those accidental substrings as words.
bool containsSearchPhrase(String text, String phrase) {
  final normalizedText = normalizeSearchText(text);
  final normalizedPhrase = normalizeSearchText(phrase);
  if (normalizedText.isEmpty || normalizedPhrase.isEmpty) return false;

  final pattern =
      normalizedPhrase.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
  return RegExp('(^|[^a-z0-9])$pattern(?=\$|[^a-z0-9])')
      .hasMatch(normalizedText);
}

enum SearchDimensionUnit { unitless, inch, millimeter, centimeter, foot }

/// A parsed dimension retaining its source unit and a canonical millimeter
/// value for comparisons between unit systems.
class SearchDimension {
  final double value;
  final SearchDimensionUnit unit;

  const SearchDimension(this.value, this.unit);

  bool get hasUnit => unit != SearchDimensionUnit.unitless;

  double get millimeters => switch (unit) {
        SearchDimensionUnit.unitless => value,
        SearchDimensionUnit.inch => value * 25.4,
        SearchDimensionUnit.millimeter => value,
        SearchDimensionUnit.centimeter => value * 10,
        SearchDimensionUnit.foot => value * 304.8,
      };

  String get unitLabel => switch (unit) {
        SearchDimensionUnit.unitless => '',
        SearchDimensionUnit.inch => 'in',
        SearchDimensionUnit.millimeter => 'mm',
        SearchDimensionUnit.centimeter => 'cm',
        SearchDimensionUnit.foot => 'ft',
      };

  @override
  bool operator ==(Object other) =>
      other is SearchDimension && value == other.value && unit == other.unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

/// Extract dimensions expressed as decimals, fractions, or integers carrying a
/// dimensional unit. Bare fractions and decimals remain unitless for backwards
/// compatibility. Bare integers are excluded so part numbers, RPM, voltage,
/// and chain sizes are not mistaken for physical dimensions.
List<SearchDimension> extractSearchDimensions(String text) {
  final normalized = normalizeSearchText(text);
  final dimensions = <SearchDimension>{};
  final dimensionPattern = RegExp(
    r'(?<![a-z0-9])(?:(\d+)(?:\s+and\s+|\s*-\s*|\s+)(\d+)\s*/\s*(\d+)|(\d+)\s*/\s*(\d+)|(\d+(?:\.\d+)?))\s*(in(?:ch(?:es)?)?|mm|millimeters?|cm|centimeters?|ft|feet|foot|[\"″])?(?=$|[^a-z0-9])',
    caseSensitive: false,
  );

  for (final match in dimensionPattern.allMatches(normalized)) {
    final unit = _parseDimensionUnit(match.group(7));
    double? value;

    final whole = double.tryParse(match.group(1) ?? '');
    final mixedNumerator = double.tryParse(match.group(2) ?? '');
    final mixedDenominator = double.tryParse(match.group(3) ?? '');
    if (whole != null &&
        mixedNumerator != null &&
        mixedDenominator != null &&
        mixedDenominator != 0) {
      value = whole + mixedNumerator / mixedDenominator;
    } else {
      final numerator = double.tryParse(match.group(4) ?? '');
      final denominator = double.tryParse(match.group(5) ?? '');
      if (numerator != null &&
          denominator != null &&
          denominator != 0 &&
          numerator < denominator) {
        value = numerator / denominator;
      } else {
        value = double.tryParse(match.group(6) ?? '');
      }
    }

    if (value == null) continue;
    final rawValue = match.group(0) ?? '';
    final isLegacyBareNumber = unit == SearchDimensionUnit.unitless &&
        (rawValue.contains('/') || rawValue.contains('.'));
    if (unit == SearchDimensionUnit.unitless && !isLegacyBareNumber) continue;
    if (unit == SearchDimensionUnit.unitless &&
        _isFollowedBySpecificationUnit(normalized, match.end)) {
      continue;
    }

    dimensions.add(SearchDimension(value, unit));
  }

  return dimensions.toList(growable: false);
}

/// Backwards-compatible numeric view used by older callers and tests.
List<double> extractSearchNumbers(String text) => extractSearchDimensions(text)
    .map((dimension) => dimension.value)
    .toSet()
    .toList(growable: false);

SearchDimensionUnit _parseDimensionUnit(String? rawUnit) {
  final unit = rawUnit?.toLowerCase() ?? '';
  if (unit.isEmpty) return SearchDimensionUnit.unitless;
  if (unit == '"' || unit == '″' || unit.startsWith('in')) {
    return SearchDimensionUnit.inch;
  }
  if (unit == 'mm' || unit.startsWith('millimeter')) {
    return SearchDimensionUnit.millimeter;
  }
  if (unit == 'cm' || unit.startsWith('centimeter')) {
    return SearchDimensionUnit.centimeter;
  }
  return SearchDimensionUnit.foot;
}

bool _isFollowedBySpecificationUnit(String text, int offset) {
  final suffix = text.substring(offset);
  return RegExp(
    r'^\s*(?:[/,\-]\s*\d+(?:\.\d+)?)*\s*(?:-\s*)?(?:(?:hp|horsepower|rpm|v|volt|volts|vac|vdc|a|amp|amps|w|watt|watts|psi|gpm|cfm|t|teeth|tooth|p|pitch|ph|phase)(?![a-z0-9])|:\s*1(?:\s*ratio)?(?![a-z0-9]))',
    caseSensitive: false,
  ).hasMatch(suffix);
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
