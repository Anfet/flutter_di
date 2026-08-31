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
///
/// ## Scope naming and lifetime
///
/// The scope is owned by the [State], not by the widget configuration. Its
/// name is read once, when the scope is opened, and is treated as immutable
/// for the rest of the state's life: a [scopeName] derived from a widget field
/// does not reopen the scope when that field changes. Put a [ValueKey] on the
/// widget when a new configuration must get a fresh scope.
///
/// The scope is released in [deactivate] and reopened in [activate], so the
/// name is free again as soon as this state leaves the tree. Flutter runs the
/// incoming state's [initState] before the outgoing state's [dispose], so
/// holding the name until [dispose] would make an ordinary element
/// replacement throw [DuplicateScopeException].
///
/// Because a deactivated state's scope is closed and rebuilt, anything
/// registered in [injectDependencies] is recreated when the state is
/// reinserted through a [GlobalKey] move. Dependencies that must survive such
/// a move belong in a parent scope.
mixin ScopeProviderState<T extends StatefulWidget> on State<T> {
  /// Globally unique name of the scope opened for this state.
  ///
  /// Read once when the scope is opened; later changes are ignored.
  String get scopeName;

  /// Optional explicit parent scope.
  ///
  /// When omitted, the scope is attached to [RootScope].
  DiScope? get parentScope => null;

  DiScope? _scope;

  /// Scope owned by this widget state.
  DiScope get scope {
    final current = _scope;
    if (current == null) {
      throw StateError(
        'scope of $runtimeType is not available: it is read either before '
        'injectDependencies() ran or after the state was disposed',
      );
    }

    return current;
  }

  @override
  void initState() {
    super.initState();
    injectDependencies();
  }

  /// Registers dependencies required by the widget state.
  ///
  /// Called from [initState], after `super.initState()`, and again whenever
  /// the state is reinserted into the tree after a [GlobalKey] move.
  @mustCallSuper
  void injectDependencies() {
    _scope = DiScope.open(scopeName, knownParentScope: parentScope);
  }

  @override
  void activate() {
    super.activate();
    // Reinserted after a GlobalKey move: deactivate() released the scope.
    if (_scope == null) {
      injectDependencies();
    }
  }

  @override
  void deactivate() {
    // Release the name before any replacing state runs initState().
    _closeScope();
    super.deactivate();
  }

  @override
  void dispose() {
    try {
      _closeScope();
    } finally {
      super.dispose();
    }
  }

  void _closeScope() {
    final current = _scope;
    if (current == null) {
      return;
    }

    _scope = null;
    current.close();
  }
}
