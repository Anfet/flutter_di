import 'package:flutter/widgets.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

/// Mixin that owns a dedicated [DiScope] for a widget state.
///
/// The scope is opened during [initState] through [injectDependencies] and is
/// automatically closed in [dispose]. Override [injectDependencies] to
/// register state-local dependencies before the widget starts building.
///
/// Each owner must supply a globally unique [scopeName]. Override [parentScope]
/// to attach the scope to an explicit parent instead of [RootScope].
///
/// If you override [injectDependencies], call `super.injectDependencies()` to
/// ensure [scope] is initialized.
mixin ScopeProviderState<T extends StatefulWidget> on State<T> {
  /// Globally unique name of the scope opened for this state.
  String get scopeName;

  /// Optional explicit parent scope.
  ///
  /// When omitted, the scope is attached to [RootScope].
  DiScope? get parentScope => null;

  /// Scope owned by this widget state.
  late final DiScope scope;

  @override
  void initState() {
    super.initState();
    injectDependencies();
  }

  /// Registers dependencies required by the widget state.
  ///
  /// Called from [initState] before `super.initState()`.
  @mustCallSuper
  void injectDependencies() {
    scope = DiScope.open(scopeName, knownParentScope: parentScope);
  }

  @override
  void dispose() {
    try {
      scope.close();
    } finally {
      super.dispose();
    }
  }
}
