// Positive compile fixture: non-nullable registration and lookup keys compile.
//
// `type_bounds_test.dart` compiles the corresponding nullable calls as
// subprocesses and verifies that each one is rejected.

// ignore_for_file: unused_local_variable

import 'package:simple_service_locator/simple_service_locator.dart';

void nullableKeysAreRejected() {
  final scope = DiScope.open('type_bounds');

  // expected_error: type_argument_not_matching_bounds
  // scope.put<String?>(null);

  // expected_error: type_argument_not_matching_bounds
  // scope.putLazy<String?>(() => null);

  // expected_error: type_argument_not_matching_bounds
  // scope.replace<String?>(null);

  // expected_error: type_argument_not_matching_bounds
  // final value = scope.find<String?>();

  // expected_error: type_argument_not_matching_bounds
  // final present = scope.contains<String?>();

  // expected_error: type_argument_not_matching_bounds
  // final evicted = scope.evict<String?>();

  // A nullable variable is rejected through inference as well:
  // String? maybe;
  // expected_error: argument_type_not_assignable
  // scope.put(maybe);

  // Non-nullable keys are the supported form.
  scope.put<String>('value');
  final resolved = scope.find<String>();

  scope.close();
}
