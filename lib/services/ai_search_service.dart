import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mro_part.dart';
import 'advanced_search_service.dart';
import 'mro_search_index.dart';

/// Public Worker endpoint injected at build time with:
/// `--dart-define=AI_SEARCH_ENDPOINT=https://.../v1/rank`.
const String configuredAISearchEndpoint = String.fromEnvironment(
  'AI_SEARCH_ENDPOINT',
);
const bool _isReleaseMode = bool.fromEnvironment('dart.vm.product');

// A const-constructor assertion is evaluated by the release compiler. This
// makes an ordinary `flutter build web --release` fail at compile time when the
// public Worker URL was not injected, while debug builds and tests remain able
// to exercise the explicit local-fallback path.
const _aiSearchReleaseConfiguration = _AISearchReleaseConfiguration(
  configuredAISearchEndpoint,
);

class _AISearchReleaseConfiguration {
  final String endpoint;

  const _AISearchReleaseConfiguration(this.endpoint)
      : assert(
          !_isReleaseMode || endpoint != '',
          'AI_SEARCH_ENDPOINT is required for release builds. Pass '
          '--dart-define=AI_SEARCH_ENDPOINT=https://<worker>/v1/rank.',
        );
}

/// AI-assisted ranking that never sends credentials from the Flutter client.
///
/// The complete local result pool is always retained. A latency-bounded subset
/// of the best locally selected records from [aiCandidatePool] is sent to the
/// Worker, and validated AI results are merged ahead of all remaining local
/// matches.
class AISearchService {
  static const int _maximumQueryLength = 500;
  // The Worker accepts up to 250 candidates and 256 KiB, but requests near
  // those protocol limits can exceed the Gemini latency budget.
  // One hundred candidates still gives Gemini twice as many choices as the 50
  // records it may return while every other match remains in the local pool.
  static const int _maximumCandidates = 100;
  static const int _maximumRequestBytes = 40 * 1024;

  final AdvancedSearchService _localSearch;
  final AdvancedSearchService _candidateSearch;
  final http.Client _client;
  final Duration timeout;
  final Uri? _endpoint;

  AISearchService({
    http.Client? client,
    AdvancedSearchService? localSearch,
    String? endpoint,
    this.timeout = const Duration(seconds: 75),
  })  : _client = client ?? http.Client(),
        _localSearch = localSearch ?? AdvancedSearchService(),
        _candidateSearch = AdvancedSearchService(),
        _endpoint = _parseEndpoint(
          endpoint ?? _aiSearchReleaseConfiguration.endpoint,
        );

  bool get isAvailable => _endpoint != null;

  /// Searches all [parts] locally, then asks the Worker to rank only the
  /// filtered [aiCandidatePool] (or all parts when it is omitted).
  ///
  /// Exact W/item, legacy, manufacturer-part, or supplier-part queries are
  /// resolved locally and never incur an AI request.
  Future<AISearchResult> search(
    List<MroPart> parts,
    String query, {
    Iterable<MroPart>? aiCandidatePool,
    MroSearchIndex? searchIndex,
  }) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return AISearchResult.local(
        results: _localSearch.search(
          parts,
          trimmedQuery,
          index: searchIndex,
        ),
      );
    }

    final exactMatches = _localSearch.exactIdentifierMatches(
      parts,
      trimmedQuery,
      index: searchIndex,
    );
    if (exactMatches.isNotEmpty) {
      return AISearchResult.exact(
        results: exactMatches
            .map(
              (part) => SearchResult(
                part: part,
                score: 100,
                matchReasons: const ['EXACT'],
                kind: SearchResultKind.exact,
              ),
            )
            .toList(growable: false),
      );
    }

    // This pool is deliberately based on all records, not the currently
    // filtered subset. The UI can therefore re-filter it without another call.
    final localResults = _localSearch.search(
      parts,
      trimmedQuery,
      index: searchIndex,
    );

    if (trimmedQuery.length > _maximumQueryLength) {
      return AISearchResult.fallback(
        results: localResults,
        error:
            'AI search queries are limited to $_maximumQueryLength characters.',
      );
    }

    if (!isAvailable) {
      return AISearchResult.fallback(
        results: localResults,
        error: 'AI search is not configured; showing local results.',
      );
    }

    final candidateSource = aiCandidatePool?.toList(growable: false) ?? parts;
    final candidates = _candidateSearch
        .searchCandidates(
          candidateSource,
          trimmedQuery,
          minimumScore: 8,
          limit: _maximumCandidates,
          index: aiCandidatePool == null ? searchIndex : null,
        )
        .map((result) => result.part)
        .toList(growable: false);

    if (candidates.isEmpty) {
      return AISearchResult.local(
        results: localResults,
        interpretation: 'No matching parts found',
      );
    }

    try {
      final request = _buildRequest(trimmedQuery, candidates);
      final response = await _client
          .post(
            _endpoint!,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: request.body,
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const _AISearchTransportException(
          'AI ranking is temporarily unavailable.',
        );
      }

      final workerResult = _parseWorkerResponse(
        response.body,
        request.candidates,
      );
      final rankedPartIds =
          workerResult.results.map((result) => result.part.stableId).toSet();
      final mergedResults = <SearchResult>[
        ...workerResult.results,
        ...localResults.where(
          (result) => !rankedPartIds.contains(result.part.stableId),
        ),
      ];

      return AISearchResult.ai(
        results: mergedResults,
        interpretation: workerResult.interpretation,
        requestId: workerResult.requestId,
        model: workerResult.model,
        tokenUsage: workerResult.tokenUsage,
      );
    } on TimeoutException {
      return AISearchResult.fallback(
        results: localResults,
        error: 'AI ranking timed out; showing local results.',
      );
    } on _AISearchTransportException catch (error) {
      return AISearchResult.fallback(
        results: localResults,
        error: '${error.message} Showing local results.',
      );
    } on http.ClientException {
      return AISearchResult.fallback(
        results: localResults,
        error: 'AI ranking is unavailable; showing local results.',
      );
    } on FormatException {
      return AISearchResult.fallback(
        results: localResults,
        error:
            'AI ranking returned an invalid response; showing local results.',
      );
    } on Object {
      // Browser/network implementations can surface platform-specific errors.
      // Keep the user-facing message provider-neutral and do not log payloads.
      return AISearchResult.fallback(
        results: localResults,
        error: 'AI ranking is unavailable; showing local results.',
      );
    }
  }

  _WorkerRequest _buildRequest(String query, List<MroPart> candidates) {
    final encodedCandidates = <Map<String, Object>>[];
    String? body;

    for (final part in candidates.take(_maximumCandidates)) {
      final candidate = <String, Object>{
        'id': encodedCandidates.length,
        'itemNumber': _bounded(part.itemName, 160),
        'legacyNumber': _bounded(part.legacyCode, 160),
        'description': _bounded(part.description, 1000),
        'manufacturer': _bounded(part.manufacturer, 160),
        'manufacturerPartNumber': _bounded(
          part.manufacturerPartNumber,
          160,
        ),
        'supplierPartNumber': _bounded(part.supplierPartNumber, 160),
        'location': _bounded(part.location, 160),
      };
      encodedCandidates.add(candidate);

      final nextBody = jsonEncode({
        'query': query,
        'candidates': encodedCandidates,
      });
      if (utf8.encode(nextBody).length > _maximumRequestBytes) {
        encodedCandidates.removeLast();
        break;
      }
      body = nextBody;
    }

    if (encodedCandidates.isEmpty || body == null) {
      throw const _AISearchTransportException(
        'AI ranking request is too large.',
      );
    }

    return _WorkerRequest(
      body: body,
      candidates:
          candidates.take(encodedCandidates.length).toList(growable: false),
    );
  }

  _WorkerResult _parseWorkerResponse(
    String responseBody,
    List<MroPart> candidates,
  ) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected an object response.');
    }

    final requestId = _requiredBoundedString(decoded['requestId'], 128);
    final model = _requiredBoundedString(decoded['model'], 80);
    if (model != 'gemini-3.6-flash') {
      throw const FormatException('Unexpected AI model.');
    }

    final interpretationValue = decoded['interpretation'];
    if (interpretationValue is! String || interpretationValue.length > 500) {
      throw const FormatException('Invalid interpretation.');
    }
    final interpretation = interpretationValue.trim();

    final rankedValue = decoded['ranked'];
    if (rankedValue is! List || rankedValue.length > 50) {
      throw const FormatException('Invalid ranked results.');
    }

    final ranked = <_ValidatedRank>[];
    final seenIds = <int>{};
    for (var position = 0; position < rankedValue.length; position++) {
      final value = rankedValue[position];
      if (value is! Map) {
        continue;
      }

      final idValue = value['id'];
      final relevanceValue = value['relevance'];
      final reasonValue = value['reason'];
      if (!_isInteger(idValue) ||
          !_isInteger(relevanceValue) ||
          reasonValue is! String ||
          reasonValue.trim().isEmpty ||
          reasonValue.length > 300) {
        continue;
      }

      final id = (idValue as num).toInt();
      final relevance = (relevanceValue as num).toInt();
      if (id < 0 ||
          id >= candidates.length ||
          relevance < 0 ||
          relevance > 100 ||
          !seenIds.add(id)) {
        continue;
      }

      ranked.add(
        _ValidatedRank(
          id: id,
          relevance: relevance,
          reason: reasonValue.trim(),
          originalPosition: position,
        ),
      );
    }

    ranked.sort((left, right) {
      final byRelevance = right.relevance.compareTo(left.relevance);
      return byRelevance != 0
          ? byRelevance
          : left.originalPosition.compareTo(right.originalPosition);
    });

    final usageValue = decoded['usage'];
    if (usageValue is! Map) {
      throw const FormatException('Invalid token usage.');
    }
    final tokenUsage = TokenUsage.fromJson(usageValue);

    return _WorkerResult(
      requestId: requestId,
      model: model,
      interpretation: interpretation,
      results: ranked
          .map(
            (rank) => SearchResult(
              part: candidates[rank.id],
              score: rank.relevance.toDouble(),
              matchReasons: [rank.reason],
              kind: SearchResultKind.ai,
              relevance: rank.relevance.toDouble(),
            ),
          )
          .toList(growable: false),
      tokenUsage: tokenUsage,
    );
  }

  static Uri? _parseEndpoint(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static String _bounded(String value, int maximumLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maximumLength) {
      return trimmed;
    }

    // Cloudflare validates JavaScript string lengths (UTF-16 code units).
    // Build the prefix by code point so truncation never leaves a dangling
    // surrogate while still honoring the Worker's exact limit.
    final result = StringBuffer();
    var length = 0;
    for (final rune in trimmed.runes) {
      final runeLength = rune > 0xFFFF ? 2 : 1;
      if (length + runeLength > maximumLength) break;
      result.writeCharCode(rune);
      length += runeLength;
    }
    return result.toString();
  }

  static bool _isInteger(Object? value) {
    return value is num && value.isFinite && value == value.roundToDouble();
  }

  static String _requiredBoundedString(Object? value, int maximumLength) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > maximumLength) {
      throw const FormatException('Invalid string field.');
    }
    return value.trim();
  }
}

class _WorkerRequest {
  final String body;
  final List<MroPart> candidates;

  const _WorkerRequest({required this.body, required this.candidates});
}

class _ValidatedRank {
  final int id;
  final int relevance;
  final String reason;
  final int originalPosition;

  const _ValidatedRank({
    required this.id,
    required this.relevance,
    required this.reason,
    required this.originalPosition,
  });
}

class _WorkerResult {
  final String requestId;
  final String model;
  final String interpretation;
  final List<SearchResult> results;
  final TokenUsage tokenUsage;

  const _WorkerResult({
    required this.requestId,
    required this.model,
    required this.interpretation,
    required this.results,
    required this.tokenUsage,
  });
}

class _AISearchTransportException implements Exception {
  final String message;

  const _AISearchTransportException(this.message);
}

/// Structured search intent retained for compatibility with the search UI.
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

  const SearchIntent({
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
      dimensions: (json['dimensions'] as List<dynamic>?)
              ?.map((dimension) => Map<String, String>.from(dimension as Map))
              .toList() ??
          const [],
      specs: Map<String, String>.from(json['specs'] as Map? ?? const {}),
      features: List<String>.from(json['features'] as List? ?? const []),
      searchSynonyms: List<String>.from(
        json['searchTerms'] as List? ??
            json['searchSynonyms'] as List? ??
            const [],
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

/// Token usage reported by the Worker for the Gemini 3.6 request.
class TokenUsage {
  static const double _inputPricePerMillion = 1.50;
  static const double _outputPricePerMillion = 7.50;

  final int inputTokens;
  final int outputTokens;
  final int thoughtTokens;
  final int totalTokens;
  final double cost;

  double get estimatedCostUsd => cost;

  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.thoughtTokens = 0,
    int? totalTokens,
    required this.cost,
  }) : totalTokens = totalTokens ?? inputTokens + outputTokens + thoughtTokens;

  factory TokenUsage.fromCounts(
    int inputTokens,
    int outputTokens, {
    int thoughtTokens = 0,
    int? totalTokens,
  }) {
    if (inputTokens < 0 || outputTokens < 0 || thoughtTokens < 0) {
      throw const FormatException('Token counts cannot be negative.');
    }
    final resolvedTotal =
        totalTokens ?? inputTokens + outputTokens + thoughtTokens;
    if (resolvedTotal < inputTokens + outputTokens + thoughtTokens) {
      throw const FormatException('Invalid total token count.');
    }

    final inputCost = (inputTokens / 1000000) * _inputPricePerMillion;
    final outputCost =
        ((outputTokens + thoughtTokens) / 1000000) * _outputPricePerMillion;
    return TokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      thoughtTokens: thoughtTokens,
      totalTokens: resolvedTotal,
      cost: inputCost + outputCost,
    );
  }

  factory TokenUsage.fromJson(Map<dynamic, dynamic> json) {
    final inputTokens = _nonNegativeInteger(json['inputTokens']);
    final outputTokens = _nonNegativeInteger(json['outputTokens']);
    final thoughtTokens = _nonNegativeInteger(json['thoughtTokens']);
    final totalTokens = _nonNegativeInteger(json['totalTokens']);
    final costValue = json['estimatedCostUsd'];
    if (costValue is! num || !costValue.isFinite || costValue < 0) {
      throw const FormatException('Invalid estimated cost.');
    }
    if (totalTokens < inputTokens + outputTokens + thoughtTokens) {
      throw const FormatException('Invalid total token count.');
    }

    return TokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      thoughtTokens: thoughtTokens,
      totalTokens: totalTokens,
      cost: costValue.toDouble(),
    );
  }

  static int _nonNegativeInteger(Object? value) {
    if (value is! num ||
        !value.isFinite ||
        value != value.roundToDouble() ||
        value < 0) {
      throw const FormatException('Invalid token count.');
    }
    return value.toInt();
  }
}

enum AISearchResultKind { ai, exact, local, fallback }

/// Result from an AI-assisted search, including an explicit fallback state.
class AISearchResult {
  final List<SearchResult> results;
  final SearchIntent? aiInterpretation;
  final bool usedAI;
  final bool usedFallback;
  final bool exactMatch;
  final String? error;
  final TokenUsage? tokenUsage;
  final String? requestId;
  final String? model;
  final AISearchResultKind kind;

  String? get fallbackMessage =>
      usedFallback ? 'AI unavailable—showing local results.' : null;

  const AISearchResult({
    required this.results,
    required this.aiInterpretation,
    required this.usedAI,
    this.usedFallback = false,
    this.exactMatch = false,
    this.error,
    this.tokenUsage,
    this.requestId,
    this.model,
    AISearchResultKind? kind,
  }) : kind = kind ??
            (usedAI
                ? AISearchResultKind.ai
                : usedFallback
                    ? AISearchResultKind.fallback
                    : exactMatch
                        ? AISearchResultKind.exact
                        : AISearchResultKind.local);

  factory AISearchResult.ai({
    required List<SearchResult> results,
    required String interpretation,
    required String requestId,
    required String model,
    required TokenUsage tokenUsage,
  }) {
    return AISearchResult(
      results: results,
      aiInterpretation: SearchIntent(
        interpretation: interpretation.isEmpty ? null : interpretation,
      ),
      usedAI: true,
      tokenUsage: tokenUsage,
      requestId: requestId,
      model: model,
      kind: AISearchResultKind.ai,
    );
  }

  factory AISearchResult.exact({required List<SearchResult> results}) {
    return AISearchResult(
      results: results,
      aiInterpretation: const SearchIntent(
        interpretation: 'Exact part-number match',
      ),
      usedAI: false,
      exactMatch: true,
      kind: AISearchResultKind.exact,
    );
  }

  factory AISearchResult.local({
    required List<SearchResult> results,
    String? interpretation,
  }) {
    return AISearchResult(
      results: results,
      aiInterpretation: interpretation == null
          ? null
          : SearchIntent(interpretation: interpretation),
      usedAI: false,
      kind: AISearchResultKind.local,
    );
  }

  factory AISearchResult.fallback({
    required List<SearchResult> results,
    required String error,
  }) {
    return AISearchResult(
      results: results,
      aiInterpretation: null,
      usedAI: false,
      usedFallback: true,
      error: error,
      kind: AISearchResultKind.fallback,
    );
  }
}
