import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

/// Mixin that binds a [DiScope] lifecycle to a [StatefulWidget] state.
///
/// A dedicated scope is opened for the state instance and automatically closed
/// in [dispose]. Override [injectDependencies] to register state-local
/// dependencies during [initState].
mixin ScopedWidgetState<T extends StatefulWidget> on State<T> {
  /// Name of the scope opened for this state.
  ///
  /// Override to provide deterministic or custom naming.
  String get scopeName => '${runtimeType}Scope';

  /// Scope owned by this widget state.
  late final DiScope scope;

  @override
  void initState() {
    injectDependencies();
    super.initState();
  }

  /// Registers dependencies required by the widget state.
  ///
  /// Called from [initState] before `super.initState()`.
  @mustCallSuper
  void injectDependencies() {
    scope = DiScope.open(scopeName);
  }

  @override
  void dispose() {
    scope.close();
    super.dispose();
  }
}
