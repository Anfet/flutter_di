import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  tearDown(() {
    RootScope.reset();
  });

  testWidgets('ScopeProviderState opens scope using an explicit scopeName',
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

  testWidgets('ScopeProviderState closes owned scope on dispose',
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

  testWidgets('ScopeProviderState attaches to an explicit parent scope',
      (tester) async {
    final parent = DiScope.open('parent_scope');
    parent.put<int>(7);
    final childKey = GlobalKey<_ChildScopeState>();

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _ChildScopeWidget(parentScope: parent, key: childKey),
    ));

    expect(childKey.currentState!.scope.find<int>(), 7);
    await tester.pumpWidget(const SizedBox.shrink());
    parent.close();
  });
}

class _NamedScopeWidget extends StatefulWidget {
  const _NamedScopeWidget({super.key});

  @override
  State<_NamedScopeWidget> createState() => _NamedScopeState();
}

class _NamedScopeState extends State<_NamedScopeWidget>
    with ScopeProviderState<_NamedScopeWidget> {
  @override
  String get scopeName => 'test_widget_scope';

  @override
  void injectDependencies() {
    super.injectDependencies();
    scope.put<int>(42);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ChildScopeWidget extends StatefulWidget {
  const _ChildScopeWidget({required this.parentScope, super.key});

  final DiScope parentScope;

  @override
  State<_ChildScopeWidget> createState() => _ChildScopeState();
}

class _ChildScopeState extends State<_ChildScopeWidget>
    with ScopeProviderState<_ChildScopeWidget> {
  @override
  String get scopeName => 'child_widget_scope';

  @override
  DiScope get parentScope => widget.parentScope;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
