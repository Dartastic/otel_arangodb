// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_arangodb_suppression.dart';

const _tracerName = 'dartastic_otel_libs_arangodb';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class ArangodbResult {
  const ArangodbResult({
    this.resultsCount,
    this.executionTimeMs,
    this.scannedFull,
    this.scannedIndex,
    this.writesExecuted,
    this.filtered,
    this.cached,
  });

  /// Number of results in the response.
  final int? resultsCount;
  final int? executionTimeMs;

  /// AQL profile: rows fully scanned (no index hit). High value =
  /// missing index.
  final int? scannedFull;

  /// AQL profile: rows scanned via index.
  final int? scannedIndex;

  /// AQL profile: number of mutation operations executed.
  final int? writesExecuted;

  /// AQL profile: rows filtered after scanning (selectivity).
  final int? filtered;

  /// True if the query plan was served from AQL plan cache.
  final bool? cached;
}

class ArangodbCallResult<T> {
  const ArangodbCallResult({required this.value, this.result});
  final T value;
  final ArangodbResult? result;
}

/// Wraps an ArangoDB AQL query or REST API call in a CLIENT span using
/// db.system=arangodb. [model] is `document`, `graph`, `kv`, `vector`,
/// `search`, or `aql` — kept distinct from the underlying op so multi-
/// model usage patterns are queryable.
Future<T> tracedArangodb<T>({
  required String operation,
  required Future<ArangodbCallResult<T>> Function() invoke,
  String model = 'aql',
  String? database,
  String? collection,
  String? statementSummary,
}) async {
  if (arangodbInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': 'arangodb',
    'db.operation.name': operation,
    'arangodb.model': model,
  };
  if (database != null) m['db.namespace'] = database;
  if (collection != null) m['db.collection.name'] = collection;
  if (statementSummary != null) m['db.statement'] = statementSummary;

  final span = _tracer().startSpan(
    'arangodb $operation${collection != null ? ' $collection' : ''}',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.resultsCount != null) {
        extras.add(OTelAPI.attributeInt(
          'arangodb.results_count',
          r.result!.resultsCount!,
        ));
      }
      if (r.result!.executionTimeMs != null) {
        extras.add(OTelAPI.attributeInt(
          'arangodb.execution_time_ms',
          r.result!.executionTimeMs!,
        ));
      }
      if (r.result!.scannedFull != null) {
        extras.add(OTelAPI.attributeInt(
          'arangodb.scanned_full',
          r.result!.scannedFull!,
        ));
      }
      if (r.result!.scannedIndex != null) {
        extras.add(OTelAPI.attributeInt(
          'arangodb.scanned_index',
          r.result!.scannedIndex!,
        ));
      }
      if (r.result!.writesExecuted != null) {
        extras.add(OTelAPI.attributeInt(
          'arangodb.writes_executed',
          r.result!.writesExecuted!,
        ));
      }
      if (r.result!.filtered != null) {
        extras.add(OTelAPI.attributeInt(
          'arangodb.filtered',
          r.result!.filtered!,
        ));
      }
      if (r.result!.cached != null) {
        extras.add(OTelAPI.attributeBool(
          'arangodb.cached',
          r.result!.cached!,
        ));
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
