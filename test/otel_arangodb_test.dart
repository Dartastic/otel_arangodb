// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_arangodb/otel_arangodb.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_arangodb-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('AQL query records profile counters', () async {
    await tracedArangodb<String>(
      operation: 'query',
      model: 'aql',
      database: 'app',
      collection: 'users',
      statementSummary:
          'FOR u IN users FILTER u.email==@email LIMIT 1 RETURN u',
      invoke: () async => const ArangodbCallResult(
        value: 'ok',
        result: ArangodbResult(
          resultsCount: 1,
          executionTimeMs: 3,
          scannedFull: 0,
          scannedIndex: 1,
          filtered: 0,
          cached: true,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('arangodb query users')!);
    expect(a['db.system'], 'arangodb');
    expect(a['arangodb.model'], 'aql');
    expect(a['arangodb.scanned_index'], 1);
    expect(a['arangodb.scanned_full'], 0);
    expect(a['arangodb.cached'], true);
  });

  test('graph traversal records model dimension', () async {
    await tracedArangodb<String>(
      operation: 'traverse',
      model: 'graph',
      collection: 'follows',
      invoke: () async => const ArangodbCallResult(
        value: 'ok',
        result: ArangodbResult(resultsCount: 24),
      ),
    );
    expect(
      attrsOf(
          spans.findSpanByName('arangodb traverse follows')!)['arangodb.model'],
      'graph',
    );
  });

  test('suppression skips spans', () async {
    await runWithoutArangodbInstrumentationAsync(() async {
      await tracedArangodb<String>(
        operation: 'query',
        invoke: () async => const ArangodbCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('arangodb '), isEmpty);
  });
}
