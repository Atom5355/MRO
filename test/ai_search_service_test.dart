import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mro_engine/models/mro_part.dart';
import 'package:mro_engine/services/advanced_search_service.dart';
import 'package:mro_engine/services/ai_search_service.dart';

void main() {
  const endpoint = 'https://mro-gemini-proxy.example.workers.dev/v1/rank';

  final bearingOne = MroPart(
    location: 'A-01',
    legacyCode: 'LEG-001',
    itemName: 'W100001',
    description: 'Sealed pillow block bearing for conveyor drive',
    manufacturer: 'Dodge',
    manufacturerPartNumber: 'P2B-SC-100',
    supplierPartNumber: 'SUP-001',
  );
  final bearingTwo = MroPart(
    location: 'A-02',
    legacyCode: 'LEG-002',
    itemName: 'W100002',
    description: 'Stainless ball bearing with one inch bore',
    manufacturer: 'SKF',
    manufacturerPartNumber: 'YAR-205',
    supplierPartNumber: 'SUP-002',
  );
  final bearingThree = MroPart(
    location: 'A-03',
    legacyCode: 'LEG-003',
    itemName: 'W100003',
    description: 'Bearing insert for washdown service',
    manufacturer: 'Timken',
    manufacturerPartNumber: 'UC-205',
    supplierPartNumber: 'SUP-003',
  );
  final parts = [bearingOne, bearingTwo, bearingThree];

  Map<String, Object> workerResponse({
    List<Map<String, Object>>? ranked,
  }) {
    return {
      'requestId': 'req-test-1',
      'model': 'gemini-3.6-flash',
      'interpretation': 'A bearing suitable for a conveyor',
      'ranked': ranked ??
          [
            {'id': 0, 'relevance': 94, 'reason': 'Strong bearing match'},
          ],
      'usage': {
        'inputTokens': 100,
        'outputTokens': 20,
        'thoughtTokens': 30,
        'totalTokens': 150,
        'estimatedCostUsd': 0.000525,
      },
    };
  }

  test('posts the bounded Worker contract and retains the full local pool',
      () async {
    late Map<String, dynamic> sentBody;
    final client = MockClient((request) async {
      expect(request.url.toString(), endpoint);
      expect(request.method, 'POST');
      expect(request.headers['content-type'], contains('application/json'));
      expect(request.headers.containsKey('x-goog-api-key'), isFalse);
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;

      return http.Response(
        jsonEncode(
          workerResponse(
            ranked: const [
              {
                'id': 0,
                'relevance': 96,
                'reason': 'Filtered conveyor match',
              },
            ],
          ),
        ),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    final service = AISearchService(client: client, endpoint: endpoint);

    final result = await service.search(
      parts,
      'bearing',
      aiCandidatePool: [bearingOne],
    );

    expect(result.usedAI, isTrue);
    expect(result.usedFallback, isFalse);
    expect(result.kind, AISearchResultKind.ai);
    expect(result.requestId, 'req-test-1');
    expect(result.model, 'gemini-3.6-flash');
    expect(result.aiInterpretation?.interpretation,
        'A bearing suitable for a conveyor');
    expect(result.results, hasLength(3));
    expect(result.results.first.part, same(bearingOne));
    expect(result.results.first.score, 96);
    expect(result.results.first.kind, SearchResultKind.ai);
    expect(result.results.first.displayLabel, '96%');
    expect(result.results.first.matchReasons, ['Filtered conveyor match']);
    expect(
      result.results.skip(1).every(
            (searchResult) => searchResult.displayLabel == 'LOCAL',
          ),
      isTrue,
    );
    expect(result.results.map((searchResult) => searchResult.part).toSet(),
        parts.toSet());

    expect(sentBody.keys, unorderedEquals(['query', 'candidates']));
    expect(sentBody['query'], 'bearing');
    final sentCandidates = sentBody['candidates'] as List<dynamic>;
    expect(sentCandidates, hasLength(1));
    expect(sentCandidates.single, {
      'id': 0,
      'itemNumber': 'W100001',
      'legacyNumber': 'LEG-001',
      'description': 'Sealed pillow block bearing for conveyor drive',
      'manufacturer': 'Dodge',
      'manufacturerPartNumber': 'P2B-SC-100',
      'supplierPartNumber': 'SUP-001',
      'location': 'A-01',
    });

    expect(result.tokenUsage?.inputTokens, 100);
    expect(result.tokenUsage?.outputTokens, 20);
    expect(result.tokenUsage?.thoughtTokens, 30);
    expect(result.tokenUsage?.totalTokens, 150);
    expect(result.tokenUsage?.cost, closeTo(0.000525, 0.000000001));
  });

  test('sorts, deduplicates, and bounds-checks ranked records', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(
          workerResponse(
            ranked: const [
              {'id': 0, 'relevance': 60, 'reason': 'lower'},
              {'id': 1, 'relevance': 99, 'reason': 'best'},
              {'id': 1, 'relevance': 80, 'reason': 'duplicate'},
              {'id': 50, 'relevance': 100, 'reason': 'out of bounds'},
              {'id': 2, 'relevance': 101, 'reason': 'bad score'},
              {'id': 2, 'relevance': 70, 'reason': 'valid'},
            ],
          ),
        ),
        200,
      );
    });
    final service = AISearchService(client: client, endpoint: endpoint);

    final result = await service.search(parts, 'bearing');

    expect(result.usedAI, isTrue);
    expect(
      result.results.take(3).map((searchResult) => searchResult.part).toSet(),
      parts.toSet(),
    );
    expect(
      result.results.take(3).map((searchResult) => searchResult.score),
      [99, 70, 60],
    );
  });

  test('missing endpoint explicitly falls back without making a request',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final service = AISearchService(client: client, endpoint: '');

    final result = await service.search(parts, 'bearing');

    expect(service.isAvailable, isFalse);
    expect(calls, 0);
    expect(result.usedAI, isFalse);
    expect(result.usedFallback, isTrue);
    expect(result.kind, AISearchResultKind.fallback);
    expect(result.fallbackMessage, 'AI unavailable—showing local results.');
    expect(result.results, isNotEmpty);
    expect(result.error, contains('not configured'));
  });

  test('malformed Worker response falls back to local results', () async {
    final client =
        MockClient((request) async => http.Response('not-json', 200));
    final service = AISearchService(client: client, endpoint: endpoint);

    final result = await service.search(parts, 'bearing');

    expect(result.usedAI, isFalse);
    expect(result.usedFallback, isTrue);
    expect(result.results, isNotEmpty);
    expect(result.error, contains('invalid response'));
  });

  test('timeout falls back to local results', () async {
    final client = MockClient((request) {
      return Future<http.Response>.delayed(
        const Duration(milliseconds: 50),
        () => http.Response(jsonEncode(workerResponse()), 200),
      );
    });
    final service = AISearchService(
      client: client,
      endpoint: endpoint,
      timeout: const Duration(milliseconds: 1),
    );

    final result = await service.search(parts, 'bearing');

    expect(result.usedAI, isFalse);
    expect(result.usedFallback, isTrue);
    expect(result.results, isNotEmpty);
    expect(result.error, contains('timed out'));
  });

  test('provider failure is sanitized and falls back locally', () async {
    const sensitiveBody = 'provider secret and raw model output';
    final client = MockClient(
      (request) async => http.Response(sensitiveBody, 503),
    );
    final service = AISearchService(client: client, endpoint: endpoint);

    final result = await service.search(parts, 'bearing');

    expect(result.usedAI, isFalse);
    expect(result.usedFallback, isTrue);
    expect(result.results, isNotEmpty);
    expect(result.error, isNot(contains(sensitiveBody)));
    expect(result.error, contains('temporarily unavailable'));
  });

  test('punctuation-insensitive exact IDs return every duplicate without AI',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(jsonEncode(workerResponse()), 200);
    });
    final duplicateOne = MroPart(
      itemName: 'W200001',
      legacyCode: 'A49-#63',
      description: 'First distinct inventory row',
    );
    final duplicateTwo = MroPart(
      itemName: 'W200002',
      legacyCode: 'A49 #63',
      description: 'Second distinct inventory row',
    );
    final service = AISearchService(client: client, endpoint: endpoint);

    final result = await service.search(
      [duplicateOne, duplicateTwo, bearingOne],
      'a49 / #63',
    );

    expect(calls, 0);
    expect(result.usedAI, isFalse);
    expect(result.usedFallback, isFalse);
    expect(result.exactMatch, isTrue);
    expect(result.kind, AISearchResultKind.exact);
    expect(result.results.map((searchResult) => searchResult.part),
        [duplicateOne, duplicateTwo]);
    expect(
      result.results.every(
        (searchResult) =>
            searchResult.kind == SearchResultKind.exact &&
            searchResult.displayLabel == 'EXACT' &&
            searchResult.matchReasons.single == 'EXACT',
      ),
      isTrue,
    );
  });

  test('TokenUsage uses current Gemini 3.6 pricing', () {
    final usage = TokenUsage.fromCounts(
      1000000,
      1000000,
      thoughtTokens: 1000000,
    );

    expect(usage.totalTokens, 3000000);
    expect(usage.cost, 16.5);
  });
}
