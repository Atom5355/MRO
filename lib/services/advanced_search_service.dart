import 'dart:math';
import '../models/mro_part.dart';
import 'mro_search_index.dart';
import 'search_text_utils.dart';

/// Advanced multi-factor search engine for MRO parts
/// Handles: part types, manufacturers, dimensions, materials, specs, RPM, HP, voltage, etc.
class AdvancedSearchService {
  MroSearchIndex? _cachedIndex;
  List<MroPart>? _cachedParts;

  // ============== PART TYPE CATEGORIES ==============
  static final Map<String, Set<String>> _partTypes = {
    'motor': {
      'motor',
      'motors',
      'gearmotor',
      'gearmotors',
      'servo',
      'servomotor',
      'ac motor',
      'dc motor',
    },
    'bearing': {
      'bearing',
      'bearings',
      'brg',
      'brgs',
      'insert bearing',
      'insert bearings',
      'bearing insert',
      'ball bearing',
      'roller bearing',
      'needle bearing',
      'thrust bearing',
      'tapered bearing',
    },
    'pump': {
      'pump',
      'pumps',
      'centrifugal pump',
      'gear pump',
      'diaphragm pump',
    },
    'valve': {
      'valve',
      'valves',
      'ball valve',
      'gate valve',
      'check valve',
      'butterfly valve',
      'solenoid valve',
    },
    'filter': {'filter', 'filters', 'strainer', 'strainers', 'element'},
    'belt': {
      'belt',
      'belts',
      'v-belt',
      'vbelt',
      'timing belt',
      'serpentine',
      'poly-v',
    },
    'chain': {'chain', 'chains', 'roller chain', 'drive chain'},
    'sprocket': {'sprocket', 'sprockets'},
    'gear': {
      'gear',
      'gears',
      'spur gear',
      'helical gear',
      'bevel gear',
      'worm gear',
    },
    'coupling': {
      'coupling',
      'couplings',
      'coupler',
      'couplers',
      'flexible coupling',
      'jaw coupling',
    },
    'seal': {
      'seal',
      'seals',
      'o-ring',
      'oring',
      'o ring',
      'gasket',
      'gaskets',
      'oil seal',
      'lip seal',
    },
    'bolt': {'bolt', 'bolts', 'cap screw', 'hex bolt', 'carriage bolt'},
    'screw': {'screw', 'screws', 'machine screw', 'set screw', 'self-tapping'},
    'nut': {'nut', 'nuts', 'hex nut', 'lock nut', 'flange nut', 'jam nut'},
    'washer': {
      'washer',
      'washers',
      'flat washer',
      'lock washer',
      'spring washer',
    },
    'bushing': {'bushing', 'bushings', 'bronze bushing', 'sleeve bushing'},
    'sleeve': {'sleeve', 'sleeves'},
    'shaft': {'shaft', 'shafts', 'drive shaft', 'input shaft', 'output shaft'},
    'roller': {'roller', 'rollers', 'conveyor roller', 'idler roller'},
    'wheel': {'wheel', 'wheels', 'caster wheel'},
    'pulley': {'pulley', 'pulleys', 'sheave', 'sheaves', 'timing pulley'},
    'hose': {'hose', 'hoses', 'hydraulic hose', 'air hose'},
    'fitting': {'fitting', 'fittings', 'pipe fitting', 'tube fitting'},
    'pipe': {'pipe', 'pipes', 'tubing', 'tube', 'tubes'},
    'elbow': {'elbow', 'elbows', '90 elbow', '45 elbow'},
    'tee': {'tee', 'tees'},
    'flange': {'flange', 'flanges', 'weld flange', 'slip-on flange'},
    'clamp': {'clamp', 'clamps', 'hose clamp', 'pipe clamp'},
    'spring': {
      'spring',
      'springs',
      'compression spring',
      'extension spring',
      'torsion spring',
    },
    'pin': {'pin', 'pins', 'cotter pin', 'dowel pin', 'roll pin', 'clevis pin'},
    'key': {'key', 'keys', 'keyway', 'keystock', 'woodruff key'},
    'sensor': {
      'sensor',
      'sensors',
      'proximity sensor',
      'temp sensor',
      'pressure sensor',
    },
    'switch': {
      'switch',
      'switches',
      'limit switch',
      'pressure switch',
      'toggle switch',
    },
    'relay': {'relay', 'relays', 'contactor', 'contactors'},
    'wire': {'wire', 'wires', 'cable', 'cables', 'conductor'},
    'connector': {'connector', 'connectors', 'terminal', 'terminals'},
    'housing': {
      'housing',
      'housings',
      'enclosure',
      'enclosures',
      'pillow block',
    },
    'cylinder': {
      'cylinder',
      'cylinders',
      'pneumatic cylinder',
      'hydraulic cylinder',
      'air cylinder',
    },
    'actuator': {'actuator', 'actuators', 'linear actuator', 'rotary actuator'},
    'drive': {'drive', 'drives', 'vfd', 'inverter', 'variable frequency'},
    'reducer': {
      'reducer',
      'reducers',
      'gearbox',
      'gearboxes',
      'gear reducer',
      'speed reducer',
    },
    'conveyor': {'conveyor', 'conveyors', 'belt conveyor'},
    'blower': {'blower', 'blowers', 'fan', 'fans', 'exhaust fan'},
    'heater': {
      'heater',
      'heaters',
      'heating element',
      'cartridge heater',
      'band heater',
    },
    'thermostat': {'thermostat', 'thermostats', 'thermocouple'},
    'gauge': {'gauge', 'gauges', 'pressure gauge', 'temp gauge'},
    'meter': {'meter', 'meters', 'flow meter'},
    'regulator': {
      'regulator',
      'regulators',
      'pressure regulator',
      'flow regulator',
    },
    'solenoid': {'solenoid', 'solenoids'},
    'brake': {'brake', 'brakes', 'motor brake'},
    'clutch': {'clutch', 'clutches'},
    'insert': {'insert', 'inserts', 'threaded insert'},
    'capacitor': {
      'capacitor',
      'capacitors',
      'cap',
      'motor start',
      'run capacitor',
    },
    'contactor': {'contactor', 'contactors'},
    'fuse': {'fuse', 'fuses', 'circuit breaker'},
    'transformer': {'transformer', 'transformers'},
  };

  // ============== MATERIALS ==============
  static final Map<String, Set<String>> _materials = {
    'stainless': {
      'stainless',
      'stainless steel',
      'ss',
      '304',
      '316',
      '303',
      '316l',
      '304l',
    },
    'steel': {'steel', 'carbon steel', 'alloy steel', 'mild steel'},
    'aluminum': {'aluminum', 'aluminium', 'alum', 'al'},
    'brass': {'brass'},
    'bronze': {'bronze', 'phosphor bronze', 'oil-impregnated bronze'},
    'copper': {'copper', 'cu'},
    'iron': {'iron', 'cast iron', 'ductile iron', 'grey iron'},
    'plastic': {
      'plastic',
      'nylon',
      'delrin',
      'acetal',
      'peek',
      'ptfe',
      'teflon',
      'uhmw',
      'hdpe',
      'pvc',
      'abs',
    },
    'rubber': {
      'rubber',
      'buna',
      'nitrile',
      'viton',
      'epdm',
      'neoprene',
      'silicone',
    },
    'chrome': {'chrome', 'chromium', 'chrome plated', 'hard chrome'},
    'zinc': {'zinc', 'galvanized', 'galv', 'zinc plated'},
    'nickel': {'nickel', 'nickel plated'},
    'titanium': {'titanium', 'ti'},
  };

  // ============== SPECIFICATIONS ==============
  static final Map<String, RegExp> _specPatterns = {
    'hp': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?|\d+\s*/\s*\d+)\s*(?:-|)?\s*(?:hp|horsepower)(?![a-z0-9])',
      caseSensitive: false,
    ),
    'rpm': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*(?:-|)?\s*rpm(?![a-z0-9])',
      caseSensitive: false,
    ),
    'voltage': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?(?:\s*[/,\-]\s*\d+(?:\.\d+)?)*)\s*(?:-|)?\s*(?:v|volt|volts|vac|vdc)(?![a-z0-9])',
      caseSensitive: false,
    ),
    'amp': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*(?:-|)?\s*(?:a|amp|amps)(?![a-z0-9])',
      caseSensitive: false,
    ),
    'watt': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*(?:-|)?\s*(?:w|watt|watts)(?![a-z0-9])',
      caseSensitive: false,
    ),
    'psi': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*(?:-|)?\s*psi(?![a-z0-9])',
      caseSensitive: false,
    ),
    'gpm': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*(?:-|)?\s*gpm(?![a-z0-9])',
      caseSensitive: false,
    ),
    'cfm': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*(?:-|)?\s*cfm(?![a-z0-9])',
      caseSensitive: false,
    ),
    'ratio': RegExp(
      r'(?<![a-z0-9])(\d+(?:\.\d+)?)\s*:\s*1\s*(?:ratio)?(?![a-z0-9])',
      caseSensitive: false,
    ),
    'teeth': RegExp(
      r'(?<![a-z0-9])(\d+)\s*(?:t|teeth|tooth)(?![a-z0-9])',
      caseSensitive: false,
    ),
    'pitch': RegExp(
      r'(?<![a-z0-9])(\d+)\s*(?:pitch|p)(?![a-z0-9])',
      caseSensitive: false,
    ),
    'phase': RegExp(
      r'(?<![a-z0-9])(\d)\s*(?:ph|phase)(?![a-z0-9])',
      caseSensitive: false,
    ),
  };

  // ============== CHAIN/BELT SIZES ==============
  // Standard ANSI roller chain sizes: 25, 35, 40, 41, 50, 60, 80, 100, 120, 140, 160, 180, 200
  static final Set<String> _chainSizes = {
    '25',
    '35',
    '40',
    '41',
    '50',
    '60',
    '80',
    '100',
    '120',
    '140',
    '160',
    '180',
    '200',
    '#25',
    '#35',
    '#40',
    '#41',
    '#50',
    '#60',
    '#80',
    '#100',
    '#120',
    '#140',
    '#160',
  };

  // Standard V-belt sizes
  static final Set<String> _beltSizes = {
    'a',
    'b',
    'c',
    'd',
    'e',
    '3l',
    '4l',
    '5l',
    '3v',
    '5v',
    '8v',
    '3vx',
    '5vx',
    'ax',
    'bx',
    'cx',
  };

  // ============== MANUFACTURERS ==============
  static final Set<String> _knownManufacturers = {
    'dodge',
    'baldor',
    'sew',
    'sew-eurodrive',
    'eurodrive',
    'fafnir',
    'skf',
    'timken',
    'nsk',
    'fag',
    'ina',
    'ntn',
    'koyo',
    'rexnord',
    'martin',
    'browning',
    'gates',
    'goodyear',
    'dayco',
    'continental',
    'parker',
    'eaton',
    'danfoss',
    'siemens',
    'abb',
    'weg',
    'leeson',
    'marathon',
    'teco',
    'nord',
    'sumitomo',
    'bonfiglioli',
    'flender',
    'renold',
    'tsubaki',
    'rexroth',
    'bosch',
    'festo',
    'smc',
    'norgren',
    'kaman',
    'link-belt',
    'linkbelt',
    'iptci',
    'peer',
    'boston gear',
    'boston',
    'bando',
    'optibelt',
    'fenner',
    'tb woods',
    'tbwoods',
    'lovejoy',
    'ruland',
    'abrasive concepts',
    'south eastern',
    'grainger',
    'mcmaster',
    'fastenal',
  };

  // ============== ATTRIBUTE WORDS (not primary types) ==============
  static final Set<String> _attributeWords = {
    'shaft',
    'bore',
    'size',
    'diameter',
    'dia',
    'id',
    'od',
    'length',
    'width',
    'height',
    'inner',
    'outer',
    'tapped',
    'threaded',
    'thread',
    'base',
    'mount',
    'mounted',
    'pillow',
    'block',
    'inch',
    'mm',
    'metric',
    'standard',
    'left',
    'right',
    'hand',
    'double',
    'single',
    'row',
    'sealed',
    'open',
    'shielded',
    'heavy',
    'duty',
    'light',
    'medium',
    'series',
    'class',
    'grade',
    'type',
    'style',
    'input',
    'output',
    'hollow',
    'solid',
    'keyed',
    'keyway',
    'splined',
    'foot',
    'flange',
    'face',
    'c-face',
    'cface',
    'd-flange',
    'dflange',
    'tefc',
    'tenv',
    'odp',
    'xp',
    'explosion proof',
    'washdown',
    'inverter duty',
  };

  // ============== FRACTIONS ==============
  static final Map<String, double> _fractions = {
    '1/16': 0.0625,
    '1/8': 0.125,
    '3/16': 0.1875,
    '1/4': 0.25,
    '5/16': 0.3125,
    '3/8': 0.375,
    '7/16': 0.4375,
    '1/2': 0.5,
    '9/16': 0.5625,
    '5/8': 0.625,
    '11/16': 0.6875,
    '3/4': 0.75,
    '13/16': 0.8125,
    '7/8': 0.875,
    '15/16': 0.9375,
  };

  /// Main search method
  List<SearchResult> search(
    List<MroPart> parts,
    String query, {
    MroSearchIndex? index,
  }) {
    return searchCandidates(
      parts,
      query,
      minimumScore: 30,
      index: index,
    );
  }

  /// Search directly against the reusable index produced by MroDataService.
  List<SearchResult> searchIndexed(MroSearchIndex index, String query) {
    return search(index.parts, query, index: index);
  }

  String describeQuery(
    String query, {
    int? resultCount,
    MroSearchIndex? index,
  }) {
    final parsedQuery = _parseQuery(
      query,
      index ?? MroSearchIndex.build(const <MroPart>[]),
    );
    final segments = <String>[];

    if (parsedQuery.primaryType != null) {
      segments.add(
        'type ${parsedQuery.primaryType} (${_confidenceLabel(parsedQuery.primaryTypeConfidence)})',
      );
    }

    if (parsedQuery.manufacturer != null) {
      segments.add(
        'manufacturer ${parsedQuery.manufacturer} (${_confidenceLabel(parsedQuery.manufacturerConfidence)})',
      );
    }

    if (parsedQuery.identifierTerms.isNotEmpty) {
      segments.add('identifier ${parsedQuery.identifierTerms.first}');
    }

    if (parsedQuery.partSize != null) {
      segments.add('size ${parsedQuery.partSize}');
    }

    if (parsedQuery.specs.isNotEmpty) {
      segments.add(
        parsedQuery.specs.entries
            .map(
              (entry) =>
                  '${entry.value.map(_formatNumber).join('/')} ${entry.key}',
            )
            .join(', '),
      );
    }

    if (parsedQuery.dimensions.isNotEmpty) {
      segments.add(
        'dimensions ${parsedQuery.dimensions.map(_formatDimension).join(', ')}',
      );
    }

    if (parsedQuery.keywords.isNotEmpty) {
      segments.add('keywords ${parsedQuery.keywords.take(3).join(', ')}');
    }

    final summary = segments.isEmpty
        ? 'Using broad text match across MRO records'
        : 'Interpreted as ${segments.join(' | ')}';

    if (resultCount == null) {
      return summary;
    }

    return '$summary | $resultCount results';
  }

  List<SearchResult> searchCandidates(
    List<MroPart> parts,
    String query, {
    double minimumScore = 30,
    int? limit,
    MroSearchIndex? index,
  }) {
    final activeIndex = _resolveIndex(parts, index);

    if (query.trim().isEmpty) {
      final allParts = activeIndex.parts
          .map((p) => SearchResult(part: p, score: 0, matchReasons: const []))
          .toList();
      return limit == null ? allParts : allParts.take(limit).toList();
    }

    final exactMatches = activeIndex.exactIdentifierMatches(query);
    if (exactMatches.isNotEmpty) {
      // Exact aliases can be duplicated in the workbook. Never collapse or
      // truncate those rows; stableId keeps them distinct downstream.
      return exactMatches
          .map(
            (part) => SearchResult(
              part: part,
              score: 1000,
              matchReasons: const ['Exact Part#'],
              kind: SearchResultKind.exact,
            ),
          )
          .toList(growable: false);
    }

    final parsedQuery = _parseQuery(query, activeIndex);
    final results = <SearchResult>[];

    for (final entry in activeIndex.entries) {
      final result = _scorePart(
        entry,
        parsedQuery,
        minimumScore: minimumScore,
      );
      if (result != null) {
        results.add(result);
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return limit == null ? results : results.take(limit).toList();
  }

  /// Return every exact, punctuation-insensitive identifier match.
  List<MroPart> exactIdentifierMatches(
    List<MroPart> parts,
    String query, {
    MroSearchIndex? index,
  }) {
    return _resolveIndex(parts, index).exactIdentifierMatches(query);
  }

  MroSearchIndex _resolveIndex(
    List<MroPart> parts,
    MroSearchIndex? suppliedIndex,
  ) {
    if (suppliedIndex != null && suppliedIndex.represents(parts)) {
      return suppliedIndex;
    }
    if (_cachedIndex != null &&
        _cachedParts != null &&
        _cachedIndex!.represents(parts)) {
      return _cachedIndex!;
    }

    _cachedParts = parts;
    _cachedIndex = MroSearchIndex.build(parts);
    return _cachedIndex!;
  }

  /// Parse the query into structured components
  _ParsedQuery _parseQuery(String query, MroSearchIndex index) {
    final normalized = normalizeSearchText(query);
    final tokens = _tokenize(normalized);
    final phrases = _buildPhrases(tokens);
    final searchableTerms = [...phrases, ...tokens];

    // 1. Find PRIMARY part type (with plural handling)
    String? primaryType;
    String? primaryMatch;
    double primaryTypeConfidence = 0.0;

    for (final term in searchableTerms) {
      if (_attributeWords.contains(term)) continue;
      final variations = getPluralVariations(term);
      for (final variant in variations) {
        for (final entry in _partTypes.entries) {
          if (entry.value.contains(variant)) {
            primaryType = entry.key;
            primaryMatch = term;
            primaryTypeConfidence = term.contains(' ') ? 1.0 : 0.8;
            break;
          }
        }
        if (primaryType != null) break;
      }
      if (primaryType != null) break;
    }

    if (primaryType == null) {
      for (final token in tokens) {
        if (_attributeWords.contains(token)) continue;
        for (final entry in _partTypes.entries) {
          for (final alias in entry.value) {
            if (_similarity(token, alias) >= 0.86) {
              primaryType = entry.key;
              primaryMatch = token;
              primaryTypeConfidence = 0.58;
              break;
            }
          }
          if (primaryType != null) break;
        }
        if (primaryType != null) break;
      }
    }

    // 2. Find MANUFACTURER
    String? manufacturer;
    double manufacturerConfidence = 0.0;
    final indexedManufacturers = index.normalizedManufacturers.keys;
    final manufacturerCandidates = (indexedManufacturers.isNotEmpty
            ? indexedManufacturers
            : _knownManufacturers)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final pattern in [
      RegExp(r'\bfrom\s+(.+)$', caseSensitive: false),
      RegExp(r'\bmade\s+by\s+(.+)$', caseSensitive: false),
      RegExp(r'\bby\s+(.+)$', caseSensitive: false),
    ]) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final explicitValue = match.group(1) ?? '';
        for (final candidate in manufacturerCandidates) {
          if (containsSearchPhrase(explicitValue, candidate)) {
            manufacturer = candidate;
            manufacturerConfidence = 1.0;
            break;
          }
        }
        if (manufacturer == null) {
          final firstExplicitToken =
              tokenizeSearchText(explicitValue).firstOrNull;
          if (firstExplicitToken != null) {
            manufacturer = firstExplicitToken;
            manufacturerConfidence = 0.72;
          }
        }
        if (manufacturer != null) break;
      }
    }

    if (manufacturer == null) {
      for (final candidate in manufacturerCandidates) {
        if (containsSearchPhrase(normalized, candidate)) {
          manufacturer = candidate;
          manufacturerConfidence = candidate.contains(' ') ? 1.0 : 0.9;
          break;
        }
      }
    }

    if (manufacturer == null) {
      for (final token in tokens) {
        if (token.length < 3) continue;
        for (final candidate in manufacturerCandidates) {
          if (candidate.contains(' ') ||
              (candidate.length - token.length).abs() > 2) {
            continue;
          }
          if (_similarity(token, candidate) >= 0.88) {
            manufacturer = candidate;
            manufacturerConfidence = 0.6;
            break;
          }
        }
        if (manufacturer != null) {
          break;
        }
      }
    }

    final materials = <String>{};
    for (final entry in _materials.entries) {
      for (final variant in entry.value) {
        if (containsSearchPhrase(normalized, variant)) {
          materials.add(entry.key);
          break;
        }
      }
    }

    // 4. Extract SPECIFICATIONS (HP, RPM, voltage, etc.)
    final specs = <String, List<double>>{};
    for (final entry in _specPatterns.entries) {
      final values = _extractSpecValues(entry.key, normalized);
      if (values.isNotEmpty) {
        specs[entry.key] = values;
      }
    }

    final specValues =
        specs.values.expand((values) => values).map(_formatNumber).toSet();
    final identifierTerms = _extractIdentifierTerms(query, tokens, specValues);

    // 5. Extract CHAIN/BELT SIZE (critical for chain/belt/sprocket searches)
    String? partSize;
    final isChainContext = primaryType == 'chain' ||
        primaryType == 'sprocket' ||
        primaryType == 'roller' ||
        normalized.contains('chain') ||
        normalized.contains('sprocket');
    final isBeltContext = primaryType == 'belt' ||
        normalized.contains('belt') ||
        normalized.contains('v-belt');

    if (isChainContext) {
      // Look for chain sizes like "50", "#50", "60", "#80"
      for (final token in tokens) {
        final cleanToken = token.replaceAll('#', '');
        if (_chainSizes.contains(token) ||
            _chainSizes.contains(cleanToken) ||
            _chainSizes.contains('#$cleanToken')) {
          partSize = cleanToken;
          break;
        }
      }
      // Also check for pattern like "50 chain" or "#50"
      final chainSizeMatch = RegExp(
        r'#?(\d{2,3})\s*(?:chain|roller|link)?',
      ).firstMatch(normalized);
      if (chainSizeMatch != null && partSize == null) {
        final size = chainSizeMatch.group(1)!;
        if (_chainSizes.contains(size) || _chainSizes.contains('#$size')) {
          partSize = size;
        }
      }
    } else if (isBeltContext) {
      // Look for belt sizes like "A", "B", "5L", "3V"
      for (final token in tokens) {
        if (_beltSizes.contains(token)) {
          partSize = token.toUpperCase();
          break;
        }
      }
    }

    // 6. Extract DIMENSIONS (numbers/fractions) - but exclude chain sizes
    final dimensions = extractSearchDimensions(query).toList(growable: true);
    // Remove the chain size from dimensions if it was detected
    if (partSize != null) {
      final partSizeNum = double.tryParse(partSize);
      if (partSizeNum != null) {
        dimensions.removeWhere(
          (dimension) =>
              !dimension.hasUnit &&
              (dimension.value - partSizeNum).abs() < 0.01,
        );
      }
    }

    // 7. Extract CRITICAL NUMBERS - numbers that appear to be part identifiers
    final criticalNumbers = <String>[];
    // Look for standalone numbers or #numbers that might be part sizes/types
    for (final match in RegExp(
      r'#?(\d{1,4})(?:\s|$|-)',
    ).allMatches(normalized)) {
      final num = match.group(1)!;
      if (num.length >= 2 && num.length <= 4) {
        criticalNumbers.add(num);
      }
    }

    // 8. Extract remaining KEYWORDS
    final keywords = <String>{};
    for (final token in tokens) {
      if (token.length < 2) continue;
      if (isSearchStopWord(token) || token == 'manufacturer') continue;
      if (token == primaryMatch) continue;
      if (token == manufacturer) continue;
      if (token == partSize) continue;
      if (identifierTerms.any((term) =>
          normalizeSearchIdentifier(term) ==
          normalizeSearchIdentifier(token))) {
        continue;
      }
      if (RegExp(r'^\d+$').hasMatch(token)) continue;
      // Skip if it's a spec unit
      if ([
        'hp',
        'rpm',
        'volt',
        'volts',
        'v',
        'amp',
        'amps',
        'a',
        'watt',
        'watts',
        'w',
        'psi',
        'gpm',
        'cfm',
        'ph',
        'phase',
      ].contains(token)) {
        continue;
      }
      keywords.add(token);
    }

    return _ParsedQuery(
      original: query,
      normalized: normalized,
      primaryType: primaryType,
      primaryMatch: primaryMatch,
      primaryTypeConfidence: primaryTypeConfidence,
      manufacturer: manufacturer,
      manufacturerConfidence: manufacturerConfidence,
      materials: materials.toList(),
      specs: specs,
      partSize: partSize,
      criticalNumbers: criticalNumbers,
      dimensions: dimensions,
      identifierTerms: identifierTerms,
      keywords: keywords.toList(),
    );
  }

  /// Score a part against the parsed query - COMPREHENSIVE MULTI-FACTOR SCORING
  SearchResult? _scorePart(
    IndexedMroPart indexedPart,
    _ParsedQuery query, {
    double minimumScore = 30,
  }) {
    final part = indexedPart.part;
    double score = 0;
    final reasons = <String>[];

    void addReason(String reason) {
      if (!reasons.contains(reason)) {
        reasons.add(reason);
      }
    }

    final itemNameLower = indexedPart.itemName;
    final descLower = indexedPart.description;
    final mfgLower = indexedPart.manufacturer;
    final partText = indexedPart.searchableText;
    final partTokens = indexedPart.tokens;
    final partDimensions = indexedPart.dimensions;

    final normalizedIdentifierTerms = query.identifierTerms
        .map(normalizeSearchIdentifier)
        .where((value) => value.isNotEmpty)
        .toSet();

    for (final queryIdentifier in normalizedIdentifierTerms) {
      if (indexedPart.identifiers.contains(queryIdentifier)) {
        score += 420;
        addReason('Exact Part#');
      } else if (queryIdentifier.length >= 4 &&
          indexedPart.identifiers.any((identifier) =>
              identifier.contains(queryIdentifier) ||
              queryIdentifier.contains(identifier))) {
        score += 220;
        addReason('Part#');
      }
    }

    // ========== RULE 1: PRIMARY TYPE ==========
    if (query.primaryType != null) {
      bool typeMatches = false;
      final typeVariants = _partTypes[query.primaryType]!;
      final typeWeight = 90 * max(query.primaryTypeConfidence, 0.35);

      // Check item name first (most accurate)
      for (final variant in typeVariants) {
        if (containsSearchPhrase(itemNameLower, variant)) {
          typeMatches = true;
          score += typeWeight;
          addReason(query.primaryType!.toUpperCase());
          break;
        }
      }

      // Then check description
      if (!typeMatches) {
        for (final variant in typeVariants) {
          if (containsSearchPhrase(descLower, variant)) {
            typeMatches = true;
            score += typeWeight * 0.72;
            addReason(query.primaryType!.toUpperCase());
            break;
          }
        }
      }

      if (!typeMatches) {
        for (final variant in typeVariants) {
          if (partTokens.contains(variant) ||
              containsSearchPhrase(partText, variant)) {
            typeMatches = true;
            score += typeWeight * 0.5;
            addReason('~${query.primaryType!.toUpperCase()}');
            break;
          }
        }
      }

      if (!typeMatches) {
        if (query.primaryTypeConfidence >= 0.9) {
          score -= 40;
        } else if (query.primaryTypeConfidence >= 0.6) {
          score -= 18;
        }
      }
    }

    // ========== RULE 2: PART SIZE (Chain #, Belt size - CRITICAL) ==========
    if (query.partSize != null) {
      final size = query.partSize!;
      final sizePattern = RegExp(
        '(^|[^0-9])#?${RegExp.escape(size)}(?:h|l|ss)?(?=\$|[^0-9])',
      );
      final sizeMatched = sizePattern.hasMatch(partText);

      if (sizeMatched) {
        score += 150; // Very high - this is exactly what they want
        addReason('#$size');
      } else {
        score -= query.primaryType == 'chain' || query.primaryType == 'belt'
            ? 120
            : 70;
      }
    }

    // ========== RULE 3: CRITICAL NUMBERS (part identifiers) ==========
    for (final num in query.criticalNumbers) {
      if (query.partSize == num) continue; // Already handled above

      final numberPattern = RegExp(
        '(^|[^0-9])#?${RegExp.escape(num)}(?=\$|[^0-9])',
      );
      if (numberPattern.hasMatch(partText)) {
        score += partText.contains('#$num') ? 50 : 30;
        addReason(num);
      }
    }

    // ========== RULE 4: MANUFACTURER (High priority) ==========
    if (query.manufacturer != null) {
      final mfgQuery = query.manufacturer!;
      bool mfgMatched = false;

      // Direct match
      if (mfgLower == mfgQuery || containsSearchPhrase(mfgLower, mfgQuery)) {
        score += 110 * max(query.manufacturerConfidence, 0.4);
        addReason('MFG:${part.manufacturer}');
        mfgMatched = true;
      } else {
        // Fuzzy match on manufacturer
        for (final mfgToken in _tokenize(mfgLower)) {
          if (_similarity(mfgQuery, mfgToken) > 0.75) {
            score += 65 * max(query.manufacturerConfidence, 0.4);
            addReason('~MFG:${part.manufacturer}');
            mfgMatched = true;
            break;
          }
        }
      }

      // Penalize non-matching when manufacturer was specified
      if (!mfgMatched) {
        if (query.manufacturerConfidence >= 0.85) {
          score -= 35;
        } else {
          score -= 12;
        }
      }
    }

    // ========== RULE 5: MATERIAL MATCH ==========
    double materialScore = 0;
    for (final mat in query.materials) {
      final matVariants = _materials[mat]!;
      for (final variant in matVariants) {
        if (containsSearchPhrase(partText, variant)) {
          materialScore += 45;
          addReason(mat.toUpperCase());
          break;
        }
      }
    }
    score += materialScore.clamp(0, 90);

    // ========== RULE 6: SPEC MATCH (HP, RPM, Voltage, etc.) ==========
    for (final entry in query.specs.entries) {
      final specName = entry.key;
      final queryValues = entry.value;
      final partValues = _extractSpecValues(specName, partText);

      if (partValues.isNotEmpty) {
        final matchedValues = queryValues
            .where(
              (queryValue) => partValues.any(
                (partValue) =>
                    _specValuesMatch(specName, queryValue, partValue),
              ),
            )
            .toList(growable: false);

        if (matchedValues.length == queryValues.length) {
          score += 80;
          addReason(
            '${queryValues.map(_formatNumber).join('/')} ${specName.toUpperCase()}',
          );
        } else if (matchedValues.isNotEmpty) {
          score += 20;
          score -= 25;
          addReason('~${specName.toUpperCase()}');
        } else {
          // A stated but incompatible specification is negative evidence, not
          // a weak positive signal.
          score -= 65;
        }
      }
    }

    // ========== RULE 7: DIMENSION MATCH ==========
    for (final qDim in query.dimensions) {
      bool dimMatched = false;
      for (final pDim in partDimensions) {
        final match = _compareDimensions(qDim, pDim);
        if (match == _DimensionMatch.exact) {
          score += 70;
          addReason(_formatDimension(qDim));
          dimMatched = true;
          break;
        } else if (match == _DimensionMatch.approximate) {
          score += 35;
          addReason('≈${_formatDimension(qDim)}');
          dimMatched = true;
          break;
        }
      }

      if (!dimMatched && partDimensions.isNotEmpty) {
        score -= 45;
      }
    }

    // ========== RULE 8: KEYWORD MATCH ==========
    int keywordsMatched = 0;
    double keywordScore = 0;
    for (final kw in query.keywords) {
      if (kw.length < 2) continue;

      // Check all plural/singular variations
      final variations = getPluralVariations(kw);
      bool matched = false;

      for (final variant in variations) {
        if (partTokens.contains(variant) ||
            containsSearchPhrase(partText, variant)) {
          keywordsMatched++;
          keywordScore += 26;
          addReason(kw);
          matched = true;
          break;
        }
      }

      if (!matched) {
        // Fuzzy match
        if (kw.length >= 3) {
          for (final pt in _tokenize(partText)) {
            if (pt.length >= 3 && _similarity(kw, pt) > 0.82) {
              keywordsMatched++;
              keywordScore += 10;
              addReason('~$kw');
              break;
            }
          }
        }
      }
    }
    score += keywordScore.clamp(0, 95);

    // Bonus for matching multiple keywords
    if (query.keywords.length >= 2 &&
        keywordsMatched >= query.keywords.length) {
      score += 40;
      addReason('All keywords');
    }

    if (query.keywords.isNotEmpty &&
        keywordsMatched == 0 &&
        query.identifierTerms.isEmpty) {
      score -= 10;
    }

    // ========== RULE 9: EXACT PHRASE MATCH (bonus) ==========
    if (query.normalized.length > 4 && partText.contains(query.normalized)) {
      score += 100;
      addReason('Exact phrase');
    }

    final evidenceCount = reasons.length;
    score += min(evidenceCount * 6, 30);

    // Minimum threshold
    if (score < minimumScore) return null;

    return SearchResult(
      part: part,
      score: score,
      matchReasons: reasons,
      kind: SearchResultKind.local,
    );
  }

  List<String> _extractIdentifierTerms(
    String rawQuery,
    List<String> tokens,
    Set<String> specValues,
  ) {
    final identifiers = <String>{};
    final normalizedSpecValues =
        specValues.map(normalizeSearchIdentifier).toSet();

    for (final token in tokenizeSearchText(rawQuery)) {
      final normalizedIdentifier = normalizeSearchIdentifier(token);
      if (normalizedIdentifier.length < 2) {
        continue;
      }

      final isMixedAlphaNumeric = RegExp(r'^(?=.*[a-z])(?=.*\d)[a-z0-9\-#/.]+$')
          .hasMatch(token.toLowerCase());
      final isStructuredNumeric = RegExp(r'^#\d{1,}$').hasMatch(token) ||
          RegExp(r'^\d{4,}$').hasMatch(token);

      if ((isMixedAlphaNumeric || isStructuredNumeric) &&
          !normalizedSpecValues.contains(normalizedIdentifier)) {
        identifiers.add(token);
      }
    }

    if (identifiers.isEmpty) {
      for (final token in tokens) {
        if (token.length >= 5 &&
            RegExp(r'[a-z]').hasMatch(token) &&
            RegExp(r'\d').hasMatch(token)) {
          identifiers.add(token);
        }
      }
    }

    return identifiers.toList();
  }

  List<String> _buildPhrases(List<String> tokens) {
    final phrases = <String>[];

    for (var index = 0; index < tokens.length - 1; index++) {
      phrases.add('${tokens[index]} ${tokens[index + 1]}');
    }

    for (var index = 0; index < tokens.length - 2; index++) {
      phrases.add('${tokens[index]} ${tokens[index + 1]} ${tokens[index + 2]}');
    }

    return phrases;
  }

  List<double> _extractSpecValues(String specName, String text) {
    final pattern = _specPatterns[specName];
    if (pattern == null) return const [];

    final values = <double>{};
    for (final match in pattern.allMatches(text)) {
      final rawValue = match.group(1) ?? '';
      if (specName == 'voltage') {
        for (final component in rawValue.split(RegExp(r'\s*[/,\-]\s*'))) {
          final value = double.tryParse(component);
          if (value != null) values.add(value);
        }
      } else {
        final value = _parseSpecNumber(rawValue);
        if (value != null) values.add(value);
      }
    }
    return values.toList(growable: false);
  }

  double? _parseSpecNumber(String rawValue) {
    final normalized = rawValue.replaceAll(RegExp(r'\s+'), '');
    final fraction = RegExp(r'^(\d+)/(\d+)$').firstMatch(normalized);
    if (fraction != null) {
      final numerator = double.tryParse(fraction.group(1) ?? '');
      final denominator = double.tryParse(fraction.group(2) ?? '');
      if (numerator != null && denominator != null && denominator != 0) {
        return numerator / denominator;
      }
    }
    return double.tryParse(normalized);
  }

  bool _specValuesMatch(String specName, double query, double part) {
    final tolerance = switch (specName) {
      'voltage' => max(query.abs() * 0.01, 0.5),
      'phase' || 'teeth' => 0.001,
      _ => max(query.abs() * 0.12, 0.5),
    };
    return (query - part).abs() <= tolerance;
  }

  _DimensionMatch _compareDimensions(
    SearchDimension query,
    SearchDimension part,
  ) {
    if (query.hasUnit && part.hasUnit) {
      final difference = (query.millimeters - part.millimeters).abs();
      if (difference <= 0.0254) return _DimensionMatch.exact;
      if (difference <= 0.8) return _DimensionMatch.approximate;
      return _DimensionMatch.none;
    }

    // A unitless fraction or decimal comes from legacy workbook text. Compare
    // its source value exactly as the old search implementation did.
    final difference = (query.value - part.value).abs();
    if (difference < 0.001) return _DimensionMatch.exact;
    if (difference < 0.03) return _DimensionMatch.approximate;
    return _DimensionMatch.none;
  }

  List<String> _tokenize(String text) {
    return tokenizeSearchText(text);
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return a == b ? 1.0 : 0.0;

    // Check if one contains the other
    if (a.contains(b) || b.contains(a)) return 0.9;

    final d = _levenshtein(a, b);
    return 1.0 - d / max(a.length, b.length);
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<int> v0 = List.generate(t.length + 1, (i) => i);
    List<int> v1 = List.filled(t.length + 1, 0);
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        v1[j + 1] = min(
          min(v1[j] + 1, v0[j + 1] + 1),
          v0[j] + (s[i] == t[j] ? 0 : 1),
        );
      }
      final tmp = v0;
      v0 = v1;
      v1 = tmp;
    }
    return v0[t.length];
  }

  String _formatNumber(double n) {
    final frac = _numberToFraction(n);
    if (frac != null) return frac;
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return n
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _formatDimension(SearchDimension dimension) {
    final value = _formatNumber(dimension.value);
    return dimension.hasUnit ? '$value ${dimension.unitLabel}' : value;
  }

  String? _numberToFraction(double n) {
    final whole = n.truncate();
    final frac = n - whole;

    for (final entry in _fractions.entries) {
      if ((frac - entry.value).abs() < 0.002) {
        return whole > 0 ? '$whole-${entry.key}' : entry.key;
      }
    }
    return null;
  }

  String _confidenceLabel(double confidence) {
    if (confidence >= 0.9) return 'high';
    if (confidence >= 0.65) return 'medium';
    return 'low';
  }
}

enum _DimensionMatch { none, approximate, exact }

class _ParsedQuery {
  final String original;
  final String normalized;
  final String? primaryType;
  final String? primaryMatch;
  final double primaryTypeConfidence;
  final String? manufacturer;
  final double manufacturerConfidence;
  final List<String> materials;
  final Map<String, List<double>> specs;
  final String? partSize; // Chain size, belt size, etc.
  final List<String> criticalNumbers; // Important part identifiers
  final List<SearchDimension> dimensions;
  final List<String> identifierTerms;
  final List<String> keywords;

  _ParsedQuery({
    required this.original,
    required this.normalized,
    required this.primaryType,
    required this.primaryMatch,
    required this.primaryTypeConfidence,
    required this.manufacturer,
    required this.manufacturerConfidence,
    required this.materials,
    required this.specs,
    required this.partSize,
    required this.criticalNumbers,
    required this.dimensions,
    required this.identifierTerms,
    required this.keywords,
  });

  @override
  String toString() {
    return 'Query{type: $primaryType@$primaryTypeConfidence, size: $partSize, mfg: $manufacturer@$manufacturerConfidence, ids: $identifierTerms, materials: $materials, specs: $specs, nums: $criticalNumbers, dims: $dimensions, kw: $keywords}';
  }
}

enum SearchResultKind { local, exact, ai }

class SearchResult {
  final MroPart part;

  /// Unbounded internal score used only for deterministic ordering.
  final double score;
  final List<String> matchReasons;
  final SearchResultKind kind;
  final double? relevance;

  SearchResult({
    required this.part,
    required this.score,
    required this.matchReasons,
    this.kind = SearchResultKind.local,
    double? relevance,
  }) : relevance = relevance?.clamp(0, 100).toDouble();

  double? get displayRelevance {
    if (kind != SearchResultKind.ai) return null;
    return relevance ?? score.clamp(0, 100).toDouble();
  }

  String get displayLabel => switch (kind) {
        SearchResultKind.exact => 'EXACT',
        SearchResultKind.local => 'LOCAL',
        SearchResultKind.ai => '${displayRelevance!.round()}%',
      };
}
