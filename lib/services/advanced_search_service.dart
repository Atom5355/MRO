import 'dart:math';
import '../models/mro_part.dart';
import 'search_text_utils.dart';

/// Advanced multi-factor search engine for MRO parts
/// Handles: part types, manufacturers, dimensions, materials, specs, RPM, HP, voltage, etc.
class AdvancedSearchService {
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
      r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*(?:hp|horsepower)',
      caseSensitive: false,
    ),
    'rpm': RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*rpm',
      caseSensitive: false,
    ),
    'voltage': RegExp(
      r'(\d+(?:/\d+)?)\s*(?:-|)?\s*(?:v|volt|volts|vac|vdc)',
      caseSensitive: false,
    ),
    'amp': RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*(?:a|amp|amps)',
      caseSensitive: false,
    ),
    'watt': RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*(?:w|watt|watts)',
      caseSensitive: false,
    ),
    'psi': RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*psi', caseSensitive: false),
    'gpm': RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*gpm', caseSensitive: false),
    'cfm': RegExp(r'(\d+(?:\.\d+)?)\s*(?:-|)?\s*cfm', caseSensitive: false),
    'ratio': RegExp(
      r'(\d+(?:\.\d+)?)\s*:\s*1\s*(?:ratio)?',
      caseSensitive: false,
    ),
    'teeth': RegExp(r'(\d+)\s*(?:t|teeth|tooth)', caseSensitive: false),
    'pitch': RegExp(r'(\d+)\s*(?:pitch|p)', caseSensitive: false),
    'phase': RegExp(r'(\d)\s*(?:ph|phase)', caseSensitive: false),
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
  List<SearchResult> search(List<MroPart> parts, String query) {
    return searchCandidates(parts, query, minimumScore: 30);
  }

  String describeQuery(String query, {int? resultCount}) {
    final parsedQuery = _parseQuery(query);
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
            .map((entry) => '${entry.value} ${entry.key}')
            .join(', '),
      );
    }

    if (parsedQuery.dimensions.isNotEmpty) {
      segments.add(
        'dimensions ${parsedQuery.dimensions.map(_formatNumber).join(', ')}',
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
  }) {
    if (query.trim().isEmpty) {
      final allParts = parts
          .take(100)
          .map((p) => SearchResult(part: p, score: 1.0, matchReasons: []))
          .toList();
      return limit == null ? allParts : allParts.take(limit).toList();
    }

    final parsedQuery = _parseQuery(query);
    final results = <SearchResult>[];

    for (final part in parts) {
      final result = _scorePart(part, parsedQuery, minimumScore: minimumScore);
      if (result != null) {
        results.add(result);
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return limit == null ? results : results.take(limit).toList();
  }

  /// Parse the query into structured components
  _ParsedQuery _parseQuery(String query) {
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
    for (final pattern in [
      RegExp(r'\bfrom\s+([a-z\-]+)', caseSensitive: false),
      RegExp(r'\bby\s+([a-z\-]+)', caseSensitive: false),
      RegExp(r'\bmade\s+by\s+([a-z\-]+)', caseSensitive: false),
    ]) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        manufacturer = match.group(1);
        manufacturerConfidence = 1.0;
        break;
      }
    }

    if (manufacturer == null) {
      for (final term in searchableTerms) {
        for (final mfg in _knownManufacturers) {
          if (term == mfg || normalized.contains(mfg)) {
            manufacturer = mfg;
            manufacturerConfidence = term.contains(' ') ? 1.0 : 0.85;
            break;
          }
        }
        if (manufacturer != null) break;
      }
    }

    if (manufacturer == null) {
      for (final token in tokens) {
        for (final mfg in _knownManufacturers) {
          if (_similarity(token, mfg) >= 0.88) {
            manufacturer = mfg;
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
        if (normalized.contains(variant)) {
          materials.add(entry.key);
          break;
        }
      }
    }

    // 4. Extract SPECIFICATIONS (HP, RPM, voltage, etc.)
    final specs = <String, String>{};
    for (final entry in _specPatterns.entries) {
      final match = entry.value.firstMatch(normalized);
      if (match != null) {
        specs[entry.key] = match.group(1)!;
      }
    }

    final identifierTerms = _extractIdentifierTerms(query, tokens, specs.values.toSet());

    // 5. Extract CHAIN/BELT SIZE (critical for chain/belt/sprocket searches)
    String? partSize;
    final isChainContext = primaryType == 'chain' ||
        primaryType == 'sprocket' ||
        primaryType == 'roller' ||
        normalized.contains('chain') ||
        normalized.contains('sprocket');
    final isBeltContext =
        primaryType == 'belt' || normalized.contains('belt') || normalized.contains('v-belt');

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
    final dimensions = _extractNumbers(query);
    // Remove the chain size from dimensions if it was detected
    if (partSize != null) {
      final partSizeNum = double.tryParse(partSize);
      if (partSizeNum != null) {
        dimensions.removeWhere((d) => (d - partSizeNum).abs() < 0.01);
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
      if (identifierTerms.any((term) => normalizeSearchIdentifier(term) == normalizeSearchIdentifier(token))) {
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
    MroPart part,
    _ParsedQuery query, {
    double minimumScore = 30,
  }) {
    double score = 0;
    final reasons = <String>[];

    void addReason(String reason) {
      if (!reasons.contains(reason)) {
        reasons.add(reason);
      }
    }

    final itemNameLower = normalizeSearchText(part.itemName);
    final descLower = normalizeSearchText(part.description);
    final mfgLower = part.normalizedManufacturer;
    final partText = part.searchableText;
    final partTokens = part.searchTokens;
    final partNumbers = _extractNumbers(partText);

    final normalizedIdentifierTerms = query.identifierTerms
        .map(normalizeSearchIdentifier)
        .where((value) => value.isNotEmpty)
        .toSet();

    for (final queryIdentifier in normalizedIdentifierTerms) {
      if (part.normalizedPartIdentifiers.contains(queryIdentifier)) {
        score += 420;
        addReason('Exact Part#');
      } else if (part.normalizedPartIdentifiers
          .any((identifier) => identifier.contains(queryIdentifier) || queryIdentifier.contains(identifier))) {
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
        if (itemNameLower.contains(variant)) {
          typeMatches = true;
          score += typeWeight;
          addReason(query.primaryType!.toUpperCase());
          break;
        }
      }

      // Then check description
      if (!typeMatches) {
        for (final variant in typeVariants) {
          if (descLower.contains(variant)) {
            typeMatches = true;
            score += typeWeight * 0.72;
            addReason(query.primaryType!.toUpperCase());
            break;
          }
        }
      }

      if (!typeMatches) {
        for (final variant in typeVariants) {
          if (partTokens.contains(variant) || partText.contains(variant)) {
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
      bool sizeMatched = false;

      // Check for exact size match with various formats
      final sizePatterns = [
        '#$size', // #50
        '$size-', // 50-
        '-$size', // -50
        ' $size ', // 50
        ',$size,', // ,50,
        '#$size-', // #50-
        '${size}h', // 50H (heavy)
        '${size}l', // 50L
        '${size}ss', // 50SS (stainless)
        RegExp(r'\b' + size + r'\b'), // word boundary match
      ];

      for (final pattern in sizePatterns) {
        if (pattern is RegExp) {
          if (pattern.hasMatch(partText)) {
            sizeMatched = true;
            break;
          }
        } else if (partText.contains(pattern as String)) {
          sizeMatched = true;
          break;
        }
      }

      if (sizeMatched) {
        score += 150; // Very high - this is exactly what they want
        addReason('#$size');
      } else {
        score -= query.primaryType == 'chain' || query.primaryType == 'belt' ? 120 : 70;
      }
    }

    // ========== RULE 3: CRITICAL NUMBERS (part identifiers) ==========
    for (final num in query.criticalNumbers) {
      if (query.partSize == num) continue; // Already handled above

      // Check if this number appears as a part identifier
      final numPatterns = ['#$num', '-$num', '$num-', ' $num '];
      bool numFound = false;
      for (final pattern in numPatterns) {
        if (partText.contains(pattern)) {
          score += 50;
          addReason('#$num');
          numFound = true;
          break;
        }
      }

      // Also check with word boundary
      if (!numFound && RegExp(r'\b' + num + r'\b').hasMatch(partText)) {
        score += 30;
        addReason(num);
      }
    }

    // ========== RULE 4: MANUFACTURER (High priority) ==========
    if (query.manufacturer != null) {
      final mfgQuery = query.manufacturer!;
      bool mfgMatched = false;

      // Direct match
      if (mfgLower.contains(mfgQuery)) {
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
        if (partText.contains(variant)) {
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
      final specValue = entry.value;

      // Build pattern to find this spec in part text
      final specPattern = _specPatterns[specName]!;
      final match = specPattern.firstMatch(partText);

      if (match != null) {
        final partValue = match.group(1)!;
        if (partValue == specValue) {
          score += 80;
          addReason('$specValue ${specName.toUpperCase()}');
        } else {
          final queryNumber = double.tryParse(specValue);
          final partNumber = double.tryParse(partValue);

          if (queryNumber != null && partNumber != null) {
            final delta = (queryNumber - partNumber).abs();
            final tolerance = max(queryNumber.abs() * 0.12, 0.5);
            if (delta <= tolerance) {
              score += 45;
              addReason('~$specValue ${specName.toUpperCase()}');
            } else {
              score += 10;
            }
          } else {
            score += 20;
          }
        }
      }
    }

    // ========== RULE 7: DIMENSION MATCH ==========
    for (final qDim in query.dimensions) {
      bool dimMatched = false;
      for (final pDim in partNumbers) {
        final diff = (qDim - pDim).abs();
        if (diff < 0.001) {
          score += 70;
          addReason(_formatNumber(qDim));
          dimMatched = true;
          break;
        } else if (diff < 0.03) {
          score += 35;
          addReason('≈${_formatNumber(qDim)}');
          dimMatched = true;
          break;
        }
      }

      // Also check for fraction string directly
      if (!dimMatched) {
        final fractionStr = _numberToFraction(qDim);
        if (fractionStr != null) {
          // Check various formats: 1-7/16, 1 7/16, 1.4375
          if (partText.contains(fractionStr) ||
              partText.contains(fractionStr.replaceAll('-', ' ')) ||
              partText.contains(
                qDim.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), ''),
              )) {
            score += 70;
            addReason(fractionStr);
          }
        }
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
        if (partText.contains(variant) || partTokens.contains(variant)) {
          keywordsMatched++;
          keywordScore += 22;
          matched = true;
          break;
        }
      }

      if (!matched) {
        // Fuzzy match
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
    score += keywordScore.clamp(0, 95);

    // Bonus for matching multiple keywords
    if (query.keywords.length >= 2 &&
        keywordsMatched >= query.keywords.length) {
      score += 40;
      addReason('All keywords');
    }

    if (query.keywords.isNotEmpty && keywordsMatched == 0 && query.identifierTerms.isEmpty) {
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

    return SearchResult(part: part, score: score, matchReasons: reasons);
  }

  List<String> _extractIdentifierTerms(
    String rawQuery,
    List<String> tokens,
    Set<String> specValues,
  ) {
    final identifiers = <String>{};

    for (final token in tokenizeSearchText(rawQuery.replaceAll('/', ' '))) {
      final normalizedIdentifier = normalizeSearchIdentifier(token);
      if (normalizedIdentifier.length < 4) {
        continue;
      }

      final isMixedAlphaNumeric = RegExp(r'^(?=.*[a-z])(?=.*\d)[a-z0-9\-#]+$')
          .hasMatch(token.toLowerCase());
      final isStructuredNumeric = RegExp(r'^#?\d{4,}$').hasMatch(token);

      if ((isMixedAlphaNumeric || isStructuredNumeric) &&
          !specValues.contains(token)) {
        identifiers.add(token);
      }
    }

    if (identifiers.isEmpty) {
      for (final token in tokens) {
        if (token.length >= 5 && RegExp(r'[a-z]').hasMatch(token) && RegExp(r'\d').hasMatch(token)) {
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

  /// Extract all numbers from text (including fractions)
  List<double> _extractNumbers(String text) {
    final numbers = <double>{};

    // Mixed fractions: "1 and 7/16", "1-7/16", "1 7/16"
    for (final pattern in [
      RegExp(r'(\d+)\s*and\s*(\d+)/(\d+)'),
      RegExp(r'(\d+)-(\d+)/(\d+)'),
      RegExp(r'(\d+)\s+(\d+)/(\d+)'),
    ]) {
      for (final m in pattern.allMatches(text)) {
        final w = int.tryParse(m.group(1) ?? '');
        final n = int.tryParse(m.group(2) ?? '');
        final d = int.tryParse(m.group(3) ?? '');
        if (w != null && n != null && d != null && d != 0) {
          numbers.add(w + n / d);
        }
      }
    }

    // Simple fractions
    for (final m in RegExp(r'(?<!\d[\s\-])(\d+)/(\d+)').allMatches(text)) {
      final n = int.tryParse(m.group(1) ?? '');
      final d = int.tryParse(m.group(2) ?? '');
      if (n != null && d != null && d != 0 && n < d) {
        numbers.add(n / d);
      }
    }

    // Decimals
    for (final m in RegExp(r'(\d+\.\d+)').allMatches(text)) {
      final num = double.tryParse(m.group(1) ?? '');
      if (num != null) numbers.add(num);
    }

    return numbers.toList();
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

class _ParsedQuery {
  final String original;
  final String normalized;
  final String? primaryType;
  final String? primaryMatch;
  final double primaryTypeConfidence;
  final String? manufacturer;
  final double manufacturerConfidence;
  final List<String> materials;
  final Map<String, String> specs;
  final String? partSize; // Chain size, belt size, etc.
  final List<String> criticalNumbers; // Important part identifiers
  final List<double> dimensions;
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

class SearchResult {
  final MroPart part;
  final double score;
  final List<String> matchReasons;

  SearchResult({
    required this.part,
    required this.score,
    required this.matchReasons,
  });
}
