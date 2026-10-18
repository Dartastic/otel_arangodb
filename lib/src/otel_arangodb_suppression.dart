// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'dart:async';

const Symbol _suppressKey = #dartastic_otel_libs_arangodb_suppress;

bool arangodbInstrumentationSuppressed() => Zone.current[_suppressKey] == true;

T runWithoutArangodbInstrumentation<T>(T Function() body) =>
    runZoned(body, zoneValues: {_suppressKey: true});

Future<T> runWithoutArangodbInstrumentationAsync<T>(
  Future<T> Function() body,
) =>
    runZoned(body, zoneValues: {_suppressKey: true});
