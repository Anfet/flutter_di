import 'package:flutter/widgets.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

/// Mixin that binds a [DiScope] lifecycle to a [StatefulWidget] state.
///
/// A dedicated scope is opened for the state instance and automatically closed
/// in [dispose]. Override [injectDependencies] to register state-local
/// dependencies during [initState].
mixin ScopedWidgetState<T extends StatefulWidget> on State<T> {
  /// Scope owned by this widget state.
  late final DiScope scope = DiScope.open('${runtimeType}Scope');

  @override
  void initState() {
    injectDependencies();
    super.initState();
  }

  @override
  void dispose() {
    scope.close();
    super.dispose();
  }

  /// Registers dependencies required by the widget state.
  ///
  /// Called from [initState] before `super.initState()`.
  void injectDependencies() {}
}
