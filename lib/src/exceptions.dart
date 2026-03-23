import 'package:simple_service_locator/src/di_scope.dart';

/// Base class for dependency-related exceptions thrown by this package.
class DependencyException implements Exception {
  /// Human-readable failure description.
  final String message;

  /// Creates a dependency exception with [message].
  DependencyException(this.message);

  @override
  String toString() {
    return 'DependencyException{message: $message}';
  }
}

/// Thrown when a requested instance cannot be resolved in a scope tree.
class InstanceNotFoundException extends DependencyException {
  /// Type that was requested.
  final Type requestedType;

  /// Optional registration tag used for lookup.
  final String? tag;

  /// Scope where lookup started.
  final DiScope scope;

  /// Creates an exception for missing [requestedType] lookup in [scope].
  InstanceNotFoundException(
    this.requestedType,
    this.scope, {
    this.tag,
  }) : super(
          "'$requestedType' with tag '${tag ?? ''}' not found in '${scope.name}' scope",
        );
}

/// Thrown when a named scope cannot be found.
class ScopeNotFoundException extends DependencyException {
  /// Missing scope name.
  final String name;

  /// Creates an exception for unknown scope [name].
  ScopeNotFoundException(this.name) : super("scope '$name' not found");
}

/// Thrown when opening a scope with a name already present in the tree.
class DuplicateScopeException extends DependencyException {
  /// Duplicated scope name.
  final String name;

  /// Scope tree root where duplication was detected.
  final DiScope scope;

  /// Creates an exception for duplicate scope [name] in [scope] tree.
  DuplicateScopeException(this.name, this.scope)
      : super("scope '$name' is already present in '${scope.name}' scope tree");
}

/// Thrown when registering an instance that conflicts with an existing one.
class DuplicateInstanceException extends DependencyException {
  /// Registration key type that conflicts.
  final Type registeredType;

  /// Concrete runtime type of the instance being registered.
  final Type instanceType;

  /// Optional registration tag used for lookup.
  final String? tag;

  /// Scope where the conflict occurred.
  final DiScope scope;

  /// Creates an exception for conflicting [registeredType] in [scope].
  DuplicateInstanceException(
    this.registeredType,
    this.scope, {
    required this.instanceType,
    this.tag,
  }) : super(
          "$registeredType (instance: $instanceType, tag: '${tag ?? ''}') is already present in '${scope.name}' scope; use replace = true",
        );
}

/// Thrown when lookup in child scopes matches more than one registration.
class MultipleInstancesFoundException extends DependencyException {
  /// Requested type used in lookup.
  final Type requestedType;

  /// Optional registration tag used for lookup.
  final String? tag;

  /// Scope where lookup started.
  final DiScope scope;

  /// Child scopes that matched the lookup.
  final List<DiScope> matches;

  /// Creates an exception for ambiguous child lookup in [scope].
  MultipleInstancesFoundException(
    this.requestedType,
    this.scope, {
    required this.matches,
    this.tag,
  }) : super(
          "multiple '$requestedType' instances with tag '${tag ?? ''}' found in child scopes of '${scope.name}': ${matches.map((s) => s.name).join(', ')}",
        );
}
