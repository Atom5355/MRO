import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
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
  final AdvancedSearchService _localSearch = AdvancedSearchService();
  static const String _modelId = 'gemini-3.1-flash-lite-preview';
  static const String _systemInstruction =
      'Use high thinking effort for ranking accuracy. Reason carefully and prioritize precise technical matching.';

  bool _initialized = false;

  AISearchService() {
    if (geminiApiKey.isNotEmpty) {
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
      developer.log('AI search error: $e', name: 'AISearchService');
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
    return _localSearch
        .searchCandidates(parts, query, minimumScore: 8, limit: 250)
        .map((result) => result.part)
        .toList();
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

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelId:generateContent?key=$geminiApiKey',
    );

    final body = {
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.5,
        'maxOutputTokens': 60000,
        'thinkingConfig': {'thinkingLevel': 'high'},
      },
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final candidatesJson = responseJson['candidates'] as List<dynamic>? ?? [];
    String text = '{}';
    if (candidatesJson.isNotEmpty) {
      final firstCandidate = candidatesJson.first as Map<String, dynamic>;
      final content = firstCandidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? [];
      final textPart = parts.cast<Map<String, dynamic>?>().firstWhere(
        (p) => (p?['text'] as String?) != null,
        orElse: () => null,
      );
      text = textPart?['text'] as String? ?? '{}';
    }

    // Extract token usage
    TokenUsage? tokenUsage;
    final usage = responseJson['usageMetadata'] as Map<String, dynamic>?;
    if (usage != null) {
      tokenUsage = TokenUsage.fromCounts(
        (usage['promptTokenCount'] as num?)?.toInt() ?? 0,
        (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0,
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
      developer.log(
        'Failed to parse AI ranking response: $text',
        name: 'AISearchService',
      );
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

  /// Calculate estimated cost based on configured AI pricing assumptions.
  /// Input: $0.25 per 1M tokens.
  /// Output: $1.50 per 1M tokens.
  factory TokenUsage.fromCounts(int inputTokens, int outputTokens) {
    final inputCost = (inputTokens / 1000000) * 0.25;
    final outputCost = (outputTokens / 1000000) * 1.5;
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
