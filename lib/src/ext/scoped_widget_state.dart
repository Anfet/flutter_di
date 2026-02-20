import 'package:flutter/widgets.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

mixin ScopedWidgetState<T extends StatefulWidget> on State<T> {
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

  void injectDependencies() {}
}
