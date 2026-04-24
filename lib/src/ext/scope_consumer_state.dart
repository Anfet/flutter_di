import 'package:flutter/widgets.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

/// Mixin that reads a named [DiScope] from the root scope tree.
///
/// Use this together with [ScopeProviderState] when one widget state owns the
/// scope and another state needs to resolve it by [scopeName].
/// The [scope] getter throws a [StateError] if no matching scope exists.
mixin ScopeConsumerState<T extends StatefulWidget> on State<T> {
  /// Name of the scope to resolve from [RootScope].
  String get scopeName;

  /// The resolved scope for this state.
  DiScope get scope =>
      RootScope.locateScope(scopeName) ??
      (throw StateError(
          'Scope consumer did not find scope named ${scopeName}'));
}
