import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  tearDown(() {
    RootScope.reset();
  });

  testWidgets('ScopedWidgetState opens scope using overridable scopeName',
      (tester) async {
    final key = GlobalKey<_NamedScopeState>();

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _NamedScopeWidget(key: key),
    ));

    final state = key.currentState!;
    expect(state.scope.name, 'test_widget_scope');
    expect(RootScope.locateScope('test_widget_scope'), isNotNull);
  });

  testWidgets('ScopedWidgetState closes owned scope on dispose',
      (tester) async {
    final key = GlobalKey<_NamedScopeState>();

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _NamedScopeWidget(key: key),
    ));
    expect(RootScope.locateScope('test_widget_scope'), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(RootScope.locateScope('test_widget_scope'), isNull);
  });
}

class _NamedScopeWidget extends StatefulWidget {
  const _NamedScopeWidget({super.key});

  @override
  State<_NamedScopeWidget> createState() => _NamedScopeState();
}

class _NamedScopeState extends State<_NamedScopeWidget>
    with ScopedWidgetState<_NamedScopeWidget> {
  @override
  String get scopeName => 'test_widget_scope';

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
