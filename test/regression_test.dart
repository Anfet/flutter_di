import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

abstract class Contract {}

class ImplA implements Contract {}

class ImplB implements Contract {}

void main() {
  tearDown(() {
    RootScope.reset();
  });

  group('replace is atomic', () {
    test('rejected replace keeps the previous registration', () {
      final scope = DiScope.open('atomic_replace');
      final original = ImplA();
      var originalDisposed = false;
      scope.put<Contract>(original, onDispose: (_) => originalDisposed = true);
      scope.put<ImplB>(ImplB());

      // ImplB key is already taken by an unrelated registration.
      expect(
        () => scope.replace<Contract>(ImplB()),
        throwsA(isA<DuplicateInstanceException>()),
      );

      expect(scope.contains<Contract>(), isTrue);
      expect(scope.find<Contract>(), same(original));
      expect(originalDisposed, isFalse);
      scope.close();
    });

    test('rejected replaceLazyAs keeps the previous registration', () {
      final scope = DiScope.open('atomic_replace_lazy');
      final original = ImplA();
      var originalDisposed = false;
      scope.put<Contract>(original, onDispose: (_) => originalDisposed = true);
      scope.put<ImplB>(ImplB());

      expect(
        () => scope.replaceLazyAs<Contract, ImplB>(ImplB.new),
        throwsA(isA<DuplicateInstanceException>()),
      );

      expect(scope.find<Contract>(), same(original));
      expect(originalDisposed, isFalse);
      scope.close();
    });

    test('replace still succeeds when only its own aliases are in the way', () {
      final scope = DiScope.open('atomic_replace_self');
      scope.put<Contract>(ImplA());
      final replacement = ImplA();

      // Contract -> ImplA and the ImplA alias both belong to the registration
      // being replaced, so they must not block the replace.
      expect(scope.replace<Contract>(replacement), same(replacement));
      expect(scope.find<Contract>(), same(replacement));
      expect(scope.find<ImplA>(), same(replacement));
      scope.close();
    });

    test('replace with registerRuntimeType: false ignores the alias key', () {
      final scope = DiScope.open('atomic_replace_no_alias');
      scope.put<Contract>(ImplA());
      scope.put<ImplB>(ImplB());
      final replacement = ImplB();

      expect(
        scope.replace<Contract>(replacement, registerRuntimeType: false),
        same(replacement),
      );
      expect(scope.find<Contract>(), same(replacement));
      scope.close();
    });

    test('replace installs the new instance after disposal fails', () {
      final scope = DiScope.open('replace_dispose_failure');
      final original = ImplA();
      final replacement = ImplB();
      final disposalError = StateError('dispose failed');
      StackTrace? disposalStackTrace;
      var notifications = 0;
      scope.put<Contract>(
        original,
        onDispose: (_) {
          try {
            throw disposalError;
          } catch (error, stackTrace) {
            disposalStackTrace = stackTrace;
            Error.throwWithStackTrace(error, stackTrace);
          }
        },
      );
      scope.addListener(() => notifications++);

      try {
        scope.replace<Contract>(replacement);
        fail('Expected the disposal error');
      } catch (error, stackTrace) {
        expect(error, same(disposalError));
        expect(stackTrace, same(disposalStackTrace));
      }

      expect(scope.find<Contract>(), same(replacement));
      expect(scope.contains<ImplA>(), isFalse);
      expect(scope.find<ImplB>(), same(replacement));
      expect(notifications, 1);
      scope.close();
    });

    test('replaceLazy keeps a lazy replacement after disposal fails', () {
      final scope = DiScope.open('replace_lazy_dispose_failure');
      final original = ImplA();
      final replacement = ImplB();
      final disposalError = StateError('dispose failed');
      StackTrace? disposalStackTrace;
      var replacementFactoryCalls = 0;
      var notifications = 0;
      scope.putLazy<Contract>(
        () => original,
        onDispose: (_) {
          try {
            throw disposalError;
          } catch (error, stackTrace) {
            disposalStackTrace = stackTrace;
            Error.throwWithStackTrace(error, stackTrace);
          }
        },
      );
      expect(scope.find<Contract>(), same(original));
      scope.addListener(() => notifications++);

      try {
        scope.replaceLazy<Contract>(() {
          replacementFactoryCalls++;
          return replacement;
        });
        fail('Expected the disposal error');
      } catch (error, stackTrace) {
        expect(error, same(disposalError));
        expect(stackTrace, same(disposalStackTrace));
      }

      expect(replacementFactoryCalls, 0);
      expect(scope.contains<Contract>(), isTrue);
      expect(scope.find<Contract>(), same(replacement));
      expect(replacementFactoryCalls, 1);
      expect(notifications, 1);
      scope.close();
    });

    test('replaceLazyAs keeps both lazy keys after disposal fails', () {
      final scope = DiScope.open('replace_lazy_as_dispose_failure');
      final original = ImplA();
      final replacement = ImplB();
      final disposalError = StateError('dispose failed');
      StackTrace? disposalStackTrace;
      var replacementFactoryCalls = 0;
      var notifications = 0;
      scope.putLazyAs<Contract, ImplA>(
        () => original,
        onDispose: (_) {
          try {
            throw disposalError;
          } catch (error, stackTrace) {
            disposalStackTrace = stackTrace;
            Error.throwWithStackTrace(error, stackTrace);
          }
        },
      );
      expect(scope.find<ImplA>(), same(original));
      scope.addListener(() => notifications++);

      try {
        scope.replaceLazyAs<Contract, ImplB>(() {
          replacementFactoryCalls++;
          return replacement;
        });
        fail('Expected the disposal error');
      } catch (error, stackTrace) {
        expect(error, same(disposalError));
        expect(stackTrace, same(disposalStackTrace));
      }

      expect(replacementFactoryCalls, 0);
      expect(scope.contains<Contract>(), isTrue);
      expect(scope.contains<ImplA>(), isFalse);
      expect(scope.contains<ImplB>(), isTrue);
      expect(scope.find<Contract>(), same(replacement));
      expect(scope.find<ImplB>(), same(replacement));
      expect(replacementFactoryCalls, 1);
      expect(notifications, 1);
      scope.close();
    });

    test('replace preserves a registration made by its disposal callback', () {
      final scope = DiScope.open('replace_reentrant_registration');
      final callbackRegistration = ImplA();
      scope.put<Contract>(
        ImplA(),
        onDispose: (_) => scope.put<Contract>(callbackRegistration),
      );

      expect(
        () => scope.replace<Contract>(ImplB()),
        throwsA(isA<DuplicateInstanceException>()),
      );
      expect(scope.find<Contract>(), same(callbackRegistration));
      scope.close();
    });

    test(
      'replace preserves a callback registration when disposal also fails',
      () {
        final scope = DiScope.open('replace_reentrant_registration_failure');
        final callbackRegistration = ImplA();
        final disposalError = StateError('dispose failed');
        StackTrace? disposalStackTrace;
        scope.put<Contract>(
          ImplA(),
          onDispose: (_) {
            scope.put<Contract>(callbackRegistration);
            try {
              throw disposalError;
            } catch (error, stackTrace) {
              disposalStackTrace = stackTrace;
              Error.throwWithStackTrace(error, stackTrace);
            }
          },
        );

        try {
          scope.replace<Contract>(ImplB());
          fail('Expected the disposal error');
        } catch (error, stackTrace) {
          expect(error, same(disposalError));
          expect(stackTrace, same(disposalStackTrace));
        }

        expect(scope.find<Contract>(), same(callbackRegistration));
        scope.close();
      },
    );

    test('replace does not reopen a scope closed by its disposal callback', () {
      final scope = DiScope.open('replace_reentrant_close');
      scope.put<Contract>(ImplA(), onDispose: (_) => scope.close());

      expect(() => scope.replace<Contract>(ImplB()), throwsStateError);
      expect(() => scope.find<Contract>(), throwsStateError);
    });

    test('replaceLazy preserves a lazy registration made by its disposer', () {
      final scope = DiScope.open('replace_lazy_reentrant_registration');
      final callbackRegistration = ImplA();
      scope.putLazy<Contract>(
        ImplA.new,
        onDispose: (_) => scope.putLazy<Contract>(() => callbackRegistration),
      );
      expect(scope.find<Contract>(), isA<ImplA>());

      expect(
        () => scope.replaceLazy<Contract>(ImplB.new),
        throwsA(isA<DuplicateInstanceException>()),
      );
      expect(scope.find<Contract>(), same(callbackRegistration));
      scope.close();
    });

    test('replaceLazy does not write into a scope closed by its disposer', () {
      final scope = DiScope.open('replace_lazy_reentrant_close');
      var replacementFactoryCalls = 0;
      scope.putLazy<Contract>(ImplA.new, onDispose: (_) => scope.close());
      expect(scope.find<Contract>(), isA<ImplA>());

      expect(
        () => scope.replaceLazy<Contract>(() {
          replacementFactoryCalls++;
          return ImplB();
        }),
        throwsStateError,
      );
      expect(replacementFactoryCalls, 0);
      expect(() => scope.find<Contract>(), throwsStateError);
    });

    test('replaceLazyAs preserves both keys registered by its disposer', () {
      final scope = DiScope.open('replace_lazy_as_reentrant_registration');
      final callbackRegistration = ImplA();
      scope.putLazyAs<Contract, ImplA>(
        ImplA.new,
        onDispose: (_) =>
            scope.putLazyAs<Contract, ImplA>(() => callbackRegistration),
      );
      expect(scope.find<Contract>(), isA<ImplA>());

      expect(
        () => scope.replaceLazyAs<Contract, ImplB>(ImplB.new),
        throwsA(isA<DuplicateInstanceException>()),
      );
      expect(scope.find<Contract>(), same(callbackRegistration));
      expect(scope.find<ImplA>(), same(callbackRegistration));
      expect(scope.contains<ImplB>(), isFalse);
      scope.close();
    });

    test(
      'replaceLazyAs does not write into a scope closed by its disposer',
      () {
        final scope = DiScope.open('replace_lazy_as_reentrant_close');
        var replacementFactoryCalls = 0;
        scope.putLazyAs<Contract, ImplA>(
          ImplA.new,
          onDispose: (_) => scope.close(),
        );
        expect(scope.find<Contract>(), isA<ImplA>());

        expect(
          () => scope.replaceLazyAs<Contract, ImplB>(() {
            replacementFactoryCalls++;
            return ImplB();
          }),
          throwsStateError,
        );
        expect(replacementFactoryCalls, 0);
        expect(() => scope.find<Contract>(), throwsStateError);
      },
    );
  });

  group('find does not mask factory errors', () {
    test('parent lazy factory failure is not reported as a miss of T', () {
      final root = DiScope.open('mask_root');
      root.putLazy<Contract>(() {
        // The factory itself fails to resolve its own dependency.
        root.find<int>();
        return ImplA();
      });
      final child = DiScope.open('mask_child', knownParentScope: root);

      try {
        child.find<Contract>();
        fail('expected the factory failure to surface');
      } on InstanceNotFoundException catch (error) {
        expect(error.requestedType, int);
      }

      root.close();
    });

    test('descendant lazy factory failure is not masked', () {
      final root = DiScope.open('mask_desc_root');
      final child = DiScope.open('mask_desc_child', knownParentScope: root);
      child.putLazy<Contract>(() {
        child.find<int>();
        return ImplA();
      });

      try {
        root.find<Contract>(searchDescendants: true);
        fail('expected the factory failure to surface');
      } on InstanceNotFoundException catch (error) {
        expect(error.requestedType, int);
      }

      root.close();
    });

    test('a genuine miss still reports the requested type and scope', () {
      final root = DiScope.open('miss_root');
      final child = DiScope.open('miss_child', knownParentScope: root);

      try {
        child.find<Contract>(tag: 'nope');
        fail('expected a miss');
      } on InstanceNotFoundException catch (error) {
        expect(error.requestedType, Contract);
        expect(error.scope, same(child));
        expect(error.tag, 'nope');
      }

      root.close();
    });
  });

  group('ambiguous descendant lookup does not materialize lazy values', () {
    test('findInChildren materializes a unique lazy match once', () {
      final root = DiScope.open('lazy_unique_children');
      final child = DiScope.open('lazy_unique_child', knownParentScope: root);
      var factoryCalls = 0;
      child.putLazy<Contract>(() {
        factoryCalls++;
        return ImplA();
      });

      expect(root.findInChildren<Contract>(), isA<ImplA>());
      expect(factoryCalls, 1);
      expect(root.findInChildren<Contract>(), isA<ImplA>());
      expect(factoryCalls, 1);
      root.close();
    });

    test(
      'find with descendant search materializes a unique lazy match once',
      () {
        final root = DiScope.open('lazy_unique_search');
        final child = DiScope.open(
          'lazy_unique_search_child',
          knownParentScope: root,
        );
        var factoryCalls = 0;
        child.putLazy<Contract>(() {
          factoryCalls++;
          return ImplA();
        });

        expect(root.find<Contract>(searchDescendants: true), isA<ImplA>());
        expect(factoryCalls, 1);
        expect(root.find<Contract>(searchDescendants: true), isA<ImplA>());
        expect(factoryCalls, 1);
        root.close();
      },
    );

    test('findInChildren detects ambiguity before invoking factories', () {
      final root = DiScope.open('lazy_ambiguous_children');
      final childA = DiScope.open('lazy_ambiguous_a', knownParentScope: root);
      final childB = DiScope.open('lazy_ambiguous_b', knownParentScope: root);
      var factoryCalls = 0;
      childA.putLazy<Contract>(() {
        factoryCalls++;
        return ImplA();
      });
      childB.putLazy<Contract>(() {
        factoryCalls++;
        return ImplB();
      });

      expect(
        () => root.findInChildren<Contract>(),
        throwsA(isA<MultipleInstancesFoundException>()),
      );
      expect(factoryCalls, 0);
      root.close();
    });

    test('find with descendant search detects ambiguity before factories', () {
      final root = DiScope.open('lazy_ambiguous_find');
      final childA = DiScope.open(
        'lazy_ambiguous_find_a',
        knownParentScope: root,
      );
      final childB = DiScope.open(
        'lazy_ambiguous_find_b',
        knownParentScope: root,
      );
      var factoryCalls = 0;
      childA.putLazy<Contract>(() {
        factoryCalls++;
        throw StateError('factory should not run');
      });
      childB.putLazy<Contract>(() {
        factoryCalls++;
        return ImplB();
      });

      expect(
        () => root.find<Contract>(searchDescendants: true),
        throwsA(isA<MultipleInstancesFoundException>()),
      );
      expect(factoryCalls, 0);
      root.close();
    });

    test('onMany eagerly resolves all ambiguous values in tree order', () {
      final root = DiScope.open('lazy_on_many');
      final childA = DiScope.open('lazy_on_many_a', knownParentScope: root);
      final childB = DiScope.open('lazy_on_many_b', knownParentScope: root);
      final factoryOrder = <String>[];
      childA.putLazy<Contract>(() {
        factoryOrder.add('a');
        return ImplA();
      });
      childB.putLazy<Contract>(() {
        factoryOrder.add('b');
        return ImplB();
      });
      List<Contract>? received;

      final result = root.findInChildren<Contract>(
        onMany: (values) {
          received = values.toList();
          return values.first;
        },
      );

      expect(result, isA<ImplA>());
      expect(factoryOrder, ['a', 'b']);
      expect(received, hasLength(2));
      root.close();
    });
  });

  group('diagnostics do not materialize lazy registrations', () {
    test('locateScopes finds a lazy scope without running the factory', () {
      final root = DiScope.open('diag_root');
      final child = DiScope.open('diag_child', knownParentScope: root);
      var factoryCalls = 0;
      child.putLazy<Contract>(() {
        factoryCalls++;
        return ImplA();
      });

      final located = root.locateScopes<Contract>();

      expect(located, contains(child));
      expect(factoryCalls, 0);
      root.close();
    });

    test('verboseTree does not run lazy factories', () {
      final scope = DiScope.open('diag_tree');
      var factoryCalls = 0;
      scope.putLazy<Contract>(() {
        factoryCalls++;
        return ImplA();
      });

      scope.verboseTree();

      expect(factoryCalls, 0);
      scope.close();
    });
  });

  group('lazy factory failures', () {
    test('a throwing factory leaves the registration retryable', () {
      final scope = DiScope.open('lazy_retry');
      var attempts = 0;
      scope.putLazy<Contract>(() {
        attempts++;
        if (attempts == 1) {
          throw StateError('first attempt fails');
        }
        return ImplA();
      });

      expect(() => scope.find<Contract>(), throwsA(isA<StateError>()));
      expect(scope.find<Contract>(), isA<ImplA>());
      expect(attempts, 2);
      scope.close();
    });
  });

  group('non-nullable registration keys', () {
    // `put<String?>(null)`, `find<String?>()` and friends are rejected by the
    // analyzer through the `T extends Object` bound, so they cannot be
    // exercised at runtime here. See test/type_bounds/nullable_rejected.dart
    // for the static fixture that documents those errors.
    test('a non-nullable key still round-trips normally', () {
      final scope = DiScope.open('non_nullable_key');
      scope.put<String>('value');

      expect(scope.contains<String>(), isTrue);
      expect(scope.find<String>(), 'value');
      scope.close();
    });

    test('an unmaterialized lazy is not disposed on close', () {
      final scope = DiScope.open('unmaterialized_dispose');
      var disposals = 0;
      scope.putLazy<Contract>(ImplA.new, onDispose: (_) => disposals++);

      scope.close();

      expect(disposals, 0);
    });

    test('a materialized lazy is disposed once on close', () {
      final scope = DiScope.open('materialized_dispose');
      var disposals = 0;
      scope.putLazy<Contract>(ImplA.new, onDispose: (_) => disposals++);
      scope.find<Contract>();

      scope.close();

      expect(disposals, 1);
    });
  });

  group('parent scope resolution by name', () {
    test('an unknown lookupParentScope name is rejected', () {
      final app = DiScope.open('lookup_app');
      app.put<int>(99);

      // A misspelled parent name must fail here, not silently attach the new
      // scope to RootScope and lose access to the intended dependencies.
      expect(
        () => DiScope.open('lookup_feature', lookupParentScope: 'lookup_ap'),
        throwsA(isA<ScopeNotFoundException>()),
      );

      app.close();
    });

    test('a known lookupParentScope name attaches to that scope', () {
      final app = DiScope.open('lookup_known_app');
      app.put<int>(99);

      final feature = DiScope.open(
        'lookup_known_feature',
        lookupParentScope: 'lookup_known_app',
      );

      expect(feature.find<int>(), 99);
      app.close();
    });

    test('omitting lookupParentScope still falls back to RootScope', () {
      RootScope.put<int>(7);
      final scope = DiScope.open('lookup_default');

      expect(scope.find<int>(), 7);
      scope.close();
    });
  });

  group('closed scopes reject presence checks', () {
    test('contains and isRegistered throw instead of answering false', () {
      final scope = DiScope.open('closed_checks');
      scope.put<Contract>(ImplA());
      scope.close();

      expect(() => scope.contains<Contract>(), throwsA(isA<StateError>()));
      expect(() => scope.containsType(Contract), throwsA(isA<StateError>()));
      expect(() => scope.isRegistered<Contract>(), throwsA(isA<StateError>()));
      expect(
        () => scope.isRegisteredType(Contract),
        throwsA(isA<StateError>()),
      );
    });

    test('an open child can still query through a live ancestor', () {
      final parent = DiScope.open('closed_checks_parent');
      parent.put<Contract>(ImplA());
      final child = DiScope.open(
        'closed_checks_child',
        knownParentScope: parent,
      );

      expect(child.isRegistered<Contract>(), isTrue);
      expect(child.contains<Contract>(), isFalse);
      parent.close();
    });
  });

  group('onMany requires descendant lookup', () {
    test('passing onMany without searchDescendants is an assertion error', () {
      final root = DiScope.open('onmany_root');
      final child = DiScope.open('onmany_child', knownParentScope: root);
      child.put<Contract>(ImplA());

      expect(
        () => root.find<Contract>(onMany: (all) => all.first),
        throwsA(isA<AssertionError>()),
      );

      root.close();
    });

    test('onMany with searchDescendants resolves ambiguity', () {
      final root = DiScope.open('onmany_ok_root');
      final a = DiScope.open('onmany_ok_a', knownParentScope: root);
      final b = DiScope.open('onmany_ok_b', knownParentScope: root);
      a.put<Contract>(ImplA());
      b.put<Contract>(ImplB());

      final resolved = root.find<Contract>(
        searchDescendants: true,
        onMany: (all) => all.first,
      );

      expect(resolved, isA<Contract>());
      root.close();
    });
  });

  group('listener reentrancy', () {
    test('a prior listener receives a later nested mutation', () async {
      final scope = DiScope.open('reentrant_deferred_notification');
      final observed = <bool>[];
      var registered = false;
      scope.addListener(() => observed.add(scope.contains<int>()));
      scope.addListener(() {
        if (!registered) {
          registered = true;
          scope.put<int>(1);
        }
      });

      scope.put<Contract>(ImplA());

      expect(observed, [false]);
      await Future<void>.delayed(Duration.zero);
      expect(observed, [false, true]);
      scope.close();
    });

    test('closing a scope cancels its pending notification', () async {
      final scope = DiScope.open('reentrant_closed_notification');
      final observed = <bool>[];
      var registered = false;
      scope.addListener(() => observed.add(scope.contains<int>()));
      scope.addListener(() {
        if (!registered) {
          registered = true;
          scope.put<int>(1);
        }
      });

      scope.put<Contract>(ImplA());
      scope.close();
      await Future<void>.delayed(Duration.zero);

      expect(observed, [false]);
    });

    test(
      'coalesces sequential nested mutations into one notification',
      () async {
        final scope = DiScope.open('reentrant_coalesced_notifications');
        final observed = <String>[];
        var registered = false;
        scope.addListener(
          () => observed.add(
            '${scope.contains<int>()}:${scope.contains<String>()}',
          ),
        );
        scope.addListener(() {
          if (!registered) {
            registered = true;
            scope.put<int>(1);
            scope.put<String>('value');
          }
        });

        scope.put<Contract>(ImplA());

        expect(observed, ['false:false']);
        await Future<void>.delayed(Duration.zero);
        expect(observed, ['false:false', 'true:true']);
        scope.close();
      },
    );

    test(
      'a mutation during the pending notification does not recurse',
      () async {
        final scope = DiScope.open('reentrant_bounded_notifications');
        var notifications = 0;
        scope.addListener(() {
          notifications++;
          if (notifications == 1) {
            scope.put<int>(1);
          } else {
            scope.put<String>('value');
          }
        });

        scope.put<Contract>(ImplA());

        await Future<void>.delayed(Duration.zero);
        expect(notifications, 2);
        expect(scope.contains<String>(), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(notifications, 2);
        scope.close();
      },
    );

    test('a listener may open a scope during an open notification', () {
      final root = DiScope.open('reentrant_open');
      DiScope? opened;
      root.addListener(() {
        opened ??= DiScope.open('reentrant_open_extra', knownParentScope: root);
      });

      DiScope.open('reentrant_open_child', knownParentScope: root);

      expect(opened, isNotNull);
      expect(RootScope.locateScope('reentrant_open_extra'), isNotNull);
      root.close();
    });

    test('a listener may register a dependency during a put notification', () {
      final scope = DiScope.open('reentrant_put');
      var registered = false;
      scope.addListener(() {
        if (!registered) {
          registered = true;
          scope.put<String>('from listener');
        }
      });

      scope.put<Contract>(ImplA());

      expect(scope.find<String>(), 'from listener');
      expect(scope.find<Contract>(), isA<ImplA>());
      scope.close();
    });

    test('a listener may close its own scope during a notification', () {
      final root = DiScope.open('reentrant_close_root');
      final child = DiScope.open(
        'reentrant_close_child',
        knownParentScope: root,
      );
      child.addListener(child.close);

      expect(() => child.put<Contract>(ImplA()), returnsNormally);
      expect(RootScope.locateScope('reentrant_close_child'), isNull);
      root.close();
    });
  });

  group('ScopeProviderState lifecycle', () {
    testWidgets('replacing a widget by key does not collide on scope name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const _ScopedWidget(key: ValueKey('first'))),
      );
      expect(RootScope.locateScope('lifecycle_scope'), isNotNull);

      await tester.pumpWidget(
        _wrap(const _ScopedWidget(key: ValueKey('second'))),
      );

      expect(tester.takeException(), isNull);
      expect(RootScope.locateScope('lifecycle_scope'), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(RootScope.locateScope('lifecycle_scope'), isNull);
    });

    testWidgets('scope name stays stable when widget configuration changes', (
      tester,
    ) async {
      final key = GlobalKey<_ConfigurableState>();
      await tester.pumpWidget(_wrap(_ConfigurableWidget(id: '1', key: key)));
      final opened = key.currentState!.scope;

      await tester.pumpWidget(_wrap(_ConfigurableWidget(id: '2', key: key)));

      // The scope belongs to the State, so it is not reopened for a new
      // configuration and its name matches the name it was opened with.
      expect(key.currentState!.scope, same(opened));
      expect(key.currentState!.scope.name, 'configurable:1');

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a GlobalKey move reopens the scope', (tester) async {
      final key = GlobalKey<_ScopedState>();
      await tester.pumpWidget(_wrap(Row(children: [_ScopedWidget(key: key)])));
      expect(key.currentState!.scope.find<int>(), 42);

      await tester.pumpWidget(
        _wrap(Column(children: [_ScopedWidget(key: key)])),
      );

      expect(tester.takeException(), isNull);
      expect(key.currentState!.scope.find<int>(), 42);
      expect(RootScope.locateScope('lifecycle_scope'), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(RootScope.locateScope('lifecycle_scope'), isNull);
    });

    testWidgets('scope is closed once the state leaves the tree', (
      tester,
    ) async {
      final key = GlobalKey<_ScopedState>();
      await tester.pumpWidget(_wrap(_ScopedWidget(key: key)));
      final scope = key.currentState!.scope;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => scope.find<int>(), throwsA(isA<StateError>()));
    });

    testWidgets('a disposal error during a GlobalKey move still reactivates', (
      tester,
    ) async {
      final key = GlobalKey<_ScopedState>();
      await tester.pumpWidget(
        _wrap(Row(children: [_ScopedWidget(key: key, throwOnDispose: true)])),
      );
      final oldScope = key.currentState!.scope;

      await tester.pumpWidget(
        _wrap(
          Column(children: [_ScopedWidget(key: key, throwOnDispose: true)]),
        ),
      );

      expect(tester.takeException(), isA<StateError>());
      expect(key.currentState, isNotNull);
      expect(key.currentState!.scope, isNot(same(oldScope)));
      expect(key.currentState!.scope.find<int>(), 42);
      expect(
        RootScope.locateScope('lifecycle_scope'),
        same(key.currentState!.scope),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(RootScope.locateScope('lifecycle_scope'), isNull);
    });

    testWidgets('a disposal error during removal still disposes the state', (
      tester,
    ) async {
      final key = GlobalKey<_ScopedState>();
      await tester.pumpWidget(
        _wrap(_ScopedWidget(key: key, throwOnDispose: true)),
      );
      final scope = key.currentState!.scope;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isA<StateError>());
      expect(key.currentState, isNull);
      expect(RootScope.locateScope('lifecycle_scope'), isNull);
      expect(() => scope.find<int>(), throwsA(isA<StateError>()));
    });
  });
}

Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

class _ScopedWidget extends StatefulWidget {
  const _ScopedWidget({this.throwOnDispose = false, super.key});

  final bool throwOnDispose;

  @override
  State<_ScopedWidget> createState() => _ScopedState();
}

class _ScopedState extends State<_ScopedWidget>
    with ScopeProviderState<_ScopedWidget> {
  bool _hasThrownDisposal = false;

  @override
  String get scopeName => 'lifecycle_scope';

  @override
  void injectDependencies() {
    super.injectDependencies();
    scope.put<int>(
      42,
      onDispose: widget.throwOnDispose
          ? (_) {
              if (!_hasThrownDisposal) {
                _hasThrownDisposal = true;
                throw StateError('dispose failed');
              }
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ConfigurableWidget extends StatefulWidget {
  const _ConfigurableWidget({required this.id, super.key});

  final String id;

  @override
  State<_ConfigurableWidget> createState() => _ConfigurableState();
}

class _ConfigurableState extends State<_ConfigurableWidget>
    with ScopeProviderState<_ConfigurableWidget> {
  @override
  String get scopeName => 'configurable:${widget.id}';

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
