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

  testWidgets('ScopeConsumerState resolves scope opened by ScopeProviderState',
      (tester) async {
    final providerKey = GlobalKey<_NamedScopeState>();
    final consumerKey = GlobalKey<_NamedScopeConsumerState>();

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          _NamedScopeWidget(key: providerKey),
          _NamedScopeConsumerWidget(key: consumerKey),
        ],
      ),
    ));

    final providerState = providerKey.currentState!;
    final consumerState = consumerKey.currentState!;

    expect(consumerState.scope, same(providerState.scope));
    expect(consumerState.scope.find<int>(), 42);
  });

  testWidgets('ScopeConsumerState throws when scope is absent', (tester) async {
    final key = GlobalKey<_NamedScopeConsumerState>();

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _NamedScopeConsumerWidget(key: key),
    ));

    expect(() => key.currentState!.scope, throwsA(isA<StateError>()));
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

class _NamedScopeConsumerWidget extends StatefulWidget {
  const _NamedScopeConsumerWidget({super.key});

  @override
  State<_NamedScopeConsumerWidget> createState() => _NamedScopeConsumerState();
}

class _NamedScopeConsumerState extends State<_NamedScopeConsumerWidget>
    with ScopeConsumerState<_NamedScopeConsumerWidget> {
  @override
  String get scopeName => 'test_widget_scope';

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
