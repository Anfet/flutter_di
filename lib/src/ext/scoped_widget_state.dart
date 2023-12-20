import 'package:flutter/widgets.dart';
import 'package:siberian_di/siberian_di.dart';

mixin ScopedWidgetState<T extends StatefulWidget> on State<T> {
  abstract DiScope scope;

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
