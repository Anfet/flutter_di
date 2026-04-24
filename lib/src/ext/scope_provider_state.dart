import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

/// Mixin that owns a dedicated [DiScope] for a widget state.
///
/// The scope is opened during [initState] through [injectDependencies] and is
/// automatically closed in [dispose]. Override [injectDependencies] to
/// register state-local dependencies before the widget starts building.
///
/// If you override [injectDependencies], call `super.injectDependencies()` to
/// ensure [scope] is initialized.
mixin ScopeProviderState<T extends StatefulWidget> on State<T> {
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
