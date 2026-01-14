import 'dart:async';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mro_part.dart';
import 'advanced_search_service.dart';

/// Gemini API Key - Available to all users
const String geminiApiKey = 'AIzaSyC1fKH3M1kaEH-0KCDHuoQg-0MJu6ZpJwc';

/// Helper class to return both results and token usage from AI ranking
class _RankingResult {
  final List<SearchResult> results;
  final TokenUsage? tokenUsage;

  _RankingResult(this.results, this.tokenUsage);
}

/// AI-powered search service using Google Gemini
/// Gemini directly evaluates and ranks parts - not just keyword extraction
class AISearchService {
  late final GenerativeModel _model;
  final AdvancedSearchService _localSearch = AdvancedSearchService();

  bool _initialized = false;

  AISearchService() {
    if (geminiApiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-3-pro-preview',
        apiKey: geminiApiKey,
        generationConfig: GenerationConfig(
          temperature: 0.5,
          maxOutputTokens: 60000, // Need more for ranking results
        ),
      );
      _initialized = true;
    }
  }

  bool get isAvailable => _initialized && geminiApiKey.isNotEmpty;

  /// Main AI-powered search - Gemini directly ranks parts
  Future<AISearchResult> search(List<MroPart> parts, String query) async {
    if (!isAvailable) {
      final results = _localSearch.search(parts, query);
      return AISearchResult(
        results: results,
        aiInterpretation: null,
        usedAI: false,
      );
    }

    try {
      // Step 1: Pre-filter to get candidate parts (fast local filtering)
      final candidates = _preFilterCandidates(parts, query);

      if (candidates.isEmpty) {
        return AISearchResult(
          results: [],
          aiInterpretation: SearchIntent(
            interpretation: 'No matching parts found',
          ),
          usedAI: true,
        );
      }

      // Step 2: Let Gemini rank the candidates
      final rankingResult = await _aiRankParts(query, candidates);

      // Extract interpretation from first result if available
      String? interpretation;
      if (rankingResult.results.isNotEmpty &&
          rankingResult.results.first.matchReasons.isNotEmpty) {
        interpretation =
            'Found ${rankingResult.results.length} matching parts for: $query';
      }

      return AISearchResult(
        results: rankingResult.results,
        aiInterpretation: SearchIntent(interpretation: interpretation),
        usedAI: true,
        tokenUsage: rankingResult.tokenUsage,
      );
    } catch (e) {
      print('AI search error: $e');
      final results = _localSearch.search(parts, query);
      return AISearchResult(
        results: results,
        aiInterpretation: null,
        usedAI: false,
        error: e.toString(),
      );
    }
  }

  /// Pre-filter parts using basic keyword matching to get candidates
  List<MroPart> _preFilterCandidates(List<MroPart> parts, String query) {
    final queryLower = query.toLowerCase();
    final queryTerms = queryLower
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.length > 1)
        .where((t) => !_stopWords.contains(t))
        .toList();

    if (queryTerms.isEmpty) return [];

    // Score each part by how many query terms it contains
    final scored = <MapEntry<MroPart, int>>[];

    for (final part in parts) {
      final searchText =
          '${part.itemName} ${part.description} ${part.manufacturer} ${part.manufacturerPartNumber}'
              .toLowerCase();

      int matches = 0;
      for (final term in queryTerms) {
        // Check all plural/singular variations of the search term
        final variations = _getPluralVariations(term);
        for (final variation in variations) {
          if (searchText.contains(variation)) {
            matches++;
            break; // Found a match for this term, move to next
          }
        }
      }

      // Also check for common part type aliases
      if (_containsPartType(searchText, queryTerms)) {
        matches += 2;
      }

      if (matches > 0) {
        scored.add(MapEntry(part, matches));
      }
    }

    // Sort by match count descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    // Return all candidates
    return scored.map((e) => e.key).toList();
  }

  bool _containsPartType(String text, List<String> queryTerms) {
    final partTypes = {
      'motor': ['motor', 'mtr', 'gearmotor'],
      'bearing': ['bearing', 'brg'],
      'belt': ['belt', 'v-belt', 'timing belt'],
      'chain': ['chain', 'roller chain'],
      'sprocket': ['sprocket', 'gear'],
      'pump': ['pump'],
      'valve': ['valve'],
      'coupling': ['coupling', 'coupler'],
    };

    for (final term in queryTerms) {
      if (partTypes.containsKey(term)) {
        for (final alias in partTypes[term]!) {
          if (text.contains(alias)) return true;
        }
      }
    }
    return false;
  }

  static const _stopWords = {
    'i',
    'a',
    'an',
    'the',
    'need',
    'want',
    'looking',
    'for',
    'with',
    'and',
    'or',
    'inch',
    'in',
  };

  /// Normalize a word to handle singular/plural forms
  /// Returns a list of variations to search for
  static List<String> _getPluralVariations(String word) {
    final variations = <String>{word};
    final lower = word.toLowerCase();

    // If ends with 's', try removing it (plural -> singular)
    if (lower.endsWith('ies')) {
      // batteries -> battery, assemblies -> assembly
      variations.add('${lower.substring(0, lower.length - 3)}y');
    } else if (lower.endsWith('es')) {
      // boxes -> box, switches -> switch, bushes -> bush
      variations.add(lower.substring(0, lower.length - 2));
      variations.add(lower.substring(0, lower.length - 1)); // cases -> case
    } else if (lower.endsWith('s') && lower.length > 2) {
      // motors -> motor, aprons -> apron
      variations.add(lower.substring(0, lower.length - 1));
    }

    // If doesn't end with 's', try adding it (singular -> plural)
    if (!lower.endsWith('s')) {
      if (lower.endsWith('y')) {
        // battery -> batteries
        variations.add('${lower.substring(0, lower.length - 1)}ies');
      } else if (lower.endsWith('x') ||
          lower.endsWith('ch') ||
          lower.endsWith('sh')) {
        // box -> boxes, switch -> switches
        variations.add('${lower}es');
      } else {
        // motor -> motors, apron -> aprons
        variations.add('${lower}s');
      }
    }

    return variations.toList();
  }

  /// Let Gemini rank and score the candidate parts
  Future<_RankingResult> _aiRankParts(
    String query,
    List<MroPart> candidates,
  ) async {
    // Format parts for Gemini
    final partsJson = candidates.asMap().entries.map((e) {
      final p = e.value;
      return {
        'id': e.key,
        'code': p.legacyCode,
        'name': p.itemName,
        'desc': p.description,
        'mfg': p.manufacturer,
        'mpn': p.manufacturerPartNumber,
      };
    }).toList();

    final prompt =
        '''You are an MRO (Maintenance, Repair, Operations) parts search expert.

USER QUERY: "$query"

CANDIDATE PARTS (JSON):
${jsonEncode(partsJson)}

TASK: Analyze the query and rank these parts by relevance. Consider:
- Part type match (motor, bearing, belt, chain, etc.)
- Specifications (HP, RPM, voltage, size, dimensions)
- Manufacturer preference
- Shaft size, bore, OD/ID dimensions
- Application fit

RESPOND WITH JSON ONLY (no markdown):
{
  "interpretation": "Brief summary of what user needs",
  "ranked": [
    {"id": 0, "score": 95, "reason": "Why this matches"},
    {"id": 2, "score": 88, "reason": "Why this matches"}
  ]
}

Rules:
- Only include parts that actually match the query intent
- Score 90-100: Excellent match (meets all criteria)
- Score 70-89: Good match (meets most criteria)  
- Score 50-69: Partial match (meets some criteria)
- Score below 50: Poor match (only include if few good matches)
- Maximum 50 results
- Order by score descending''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{}';

    // Extract token usage
    TokenUsage? tokenUsage;
    if (response.usageMetadata != null) {
      final metadata = response.usageMetadata!;
      tokenUsage = TokenUsage.fromCounts(
        metadata.promptTokenCount ?? 0,
        metadata.candidatesTokenCount ?? 0,
      );
    }

    try {
      String cleanJson = text.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```json?\s*'), '');
        cleanJson = cleanJson.replaceAll(RegExp(r'\s*```$'), '');
      }
      cleanJson = cleanJson.trim();

      final json = jsonDecode(cleanJson) as Map<String, dynamic>;
      final ranked = json['ranked'] as List<dynamic>? ?? [];

      final results = <SearchResult>[];
      for (final item in ranked) {
        final id = item['id'] as int;
        if (id >= 0 && id < candidates.length) {
          results.add(
            SearchResult(
              part: candidates[id],
              score: (item['score'] as num).toDouble(),
              matchReasons: [item['reason'] as String? ?? 'AI match'],
            ),
          );
        }
      }

      return _RankingResult(results, tokenUsage);
    } catch (e) {
      print('Failed to parse AI ranking response: $text');
      // Return candidates with basic ordering
      final fallbackResults = candidates
          .asMap()
          .entries
          .map(
            (e) => SearchResult(
              part: e.value,
              score: (100 - e.key).toDouble(),
              matchReasons: ['Keyword match'],
            ),
          )
          .take(50)
          .toList();
      return _RankingResult(fallbackResults, tokenUsage);
    }
  }
}

/// Structured search intent extracted by AI
class SearchIntent {
  final String? partType;
  final String? manufacturer;
  final String? material;
  final String? partSize;
  final List<Map<String, String>> dimensions;
  final Map<String, String> specs;
  final List<String> features;
  final List<String> searchSynonyms;
  final String? clarification;
  final double confidence;
  final String? interpretation;

  SearchIntent({
    this.partType,
    this.manufacturer,
    this.material,
    this.partSize,
    this.dimensions = const [],
    this.specs = const {},
    this.features = const [],
    this.searchSynonyms = const [],
    this.clarification,
    this.confidence = 0.5,
    this.interpretation,
  });

  factory SearchIntent.fromJson(Map<String, dynamic> json) {
    return SearchIntent(
      partType: json['partType'] as String?,
      manufacturer: json['manufacturer'] as String?,
      material: json['material'] as String?,
      partSize: json['partSize'] as String?,
      dimensions:
          (json['dimensions'] as List<dynamic>?)
              ?.map((d) => Map<String, String>.from(d as Map))
              .toList() ??
          [],
      specs: Map<String, String>.from(json['specs'] as Map? ?? {}),
      features: List<String>.from(json['features'] as List? ?? []),
      searchSynonyms: List<String>.from(
        json['searchTerms'] as List? ?? json['searchSynonyms'] as List? ?? [],
      ),
      clarification: json['clarification'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      interpretation: json['interpretation'] as String?,
    );
  }

  @override
  String toString() {
    return 'SearchIntent{type: $partType, mfg: $manufacturer, specs: $specs}';
  }
}

/// Token usage information from AI API
class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final double cost;

  TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
  });

  /// Calculate cost based on Gemini 3 Pro pricing
  /// Input: $2.00 per 1M tokens (for prompts <= 200k)
  /// Output: $12.00 per 1M tokens (for prompts <= 200k)
  factory TokenUsage.fromCounts(int inputTokens, int outputTokens) {
    final inputCost = (inputTokens / 1000000) * 2.0;
    final outputCost = (outputTokens / 1000000) * 12.0;
    final totalCost = inputCost + outputCost;

    return TokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cost: totalCost,
    );
  }
}

/// Result from AI-powered search
class AISearchResult {
  final List<SearchResult> results;
  final SearchIntent? aiInterpretation;
  final bool usedAI;
  final String? error;
  final TokenUsage? tokenUsage;

  AISearchResult({
    required this.results,
    required this.aiInterpretation,
    required this.usedAI,
    this.error,
    this.tokenUsage,
  });
}
