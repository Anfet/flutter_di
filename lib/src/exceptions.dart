import 'package:siberian_di/src/di_scope.dart';

class DependencyException implements Exception {
  final String message;

  DependencyException(this.message);

  @override
  String toString() {
    return 'DependencyException{message: $message}';
  }
}

class InstanceNotFoundException extends DependencyException {
  final Type type;
  final DiScope scope;

  InstanceNotFoundException(this.type, this.scope) : super("'$type' not found in '${scope.name}' scope");
}

class DuplicateInstanceException extends DependencyException {
  final Type type;
  final DiScope scope;

  DuplicateInstanceException(this.type, this.scope) : super("$type is already present in '${scope.name}' scope; use replace = true");
}
