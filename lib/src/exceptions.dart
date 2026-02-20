import 'package:simple_service_locator/src/di_scope.dart';

class DependencyException implements Exception {
  final String message;

  DependencyException(this.message);

  @override
  String toString() {
    return 'DependencyException{message: $message}';
  }
}

class InstanceNotFoundException extends DependencyException {
  final Type requestedType;
  final String? tag;
  final DiScope scope;

  InstanceNotFoundException(
    this.requestedType,
    this.scope, {
    this.tag,
  }) : super(
          "'$requestedType' with tag '${tag ?? ''}' not found in '${scope.name}' scope",
        );
}

class ScopeNotFoundException extends DependencyException {
  final String name;

  ScopeNotFoundException(this.name) : super("scope '$name' not found");
}

class DuplicateScopeException extends DependencyException {
  final String name;
  final DiScope scope;

  DuplicateScopeException(this.name, this.scope) : super("scope '$name' is already present in '${scope.name}' scope tree");
}

class DuplicateInstanceException extends DependencyException {
  final Type registeredType;
  final Type instanceType;
  final String? tag;
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
