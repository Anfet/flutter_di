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

  ScopeNotFoundException(this.name) : super("scope '$name' not found");
}

/// Thrown when opening a scope with a name already present in the tree.
class DuplicateScopeException extends DependencyException {
  /// Duplicated scope name.
  final String name;

  /// Scope tree root where duplication was detected.
  final DiScope scope;

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

  DuplicateInstanceException(
    this.registeredType,
    this.scope, {
    required this.instanceType,
    this.tag,
  }) : super(
          "$registeredType (instance: $instanceType, tag: '${tag ?? ''}') is already present in '${scope.name}' scope; use replace = true",
        );
}
