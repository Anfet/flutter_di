/// A lightweight scoped service locator for Flutter and Dart applications.
///
/// Import this library to access:
/// - [DiScope] for dependency registration and lookup.
/// - typed exceptions describing dependency lookup/registration errors.
/// - [ScopeProviderState] and [ScopeConsumerState] for widget-bound scope
///   lifecycle management.
library simple_service_locator;

export 'src/di_scope.dart';
export 'src/exceptions.dart';
export 'src/ext/scope_provider_state.dart';
export 'src/ext/scope_consumer_state.dart';
