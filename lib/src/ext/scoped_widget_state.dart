import 'package:flutter/widgets.dart';
import 'package:flutter_di/flutter_di.dart';

mixin ScopedWidgetState<T extends StatefulWidget> on State<T> {
  late final DiScope scope = DiScope.open('${this.runtimeType}Scope');

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
