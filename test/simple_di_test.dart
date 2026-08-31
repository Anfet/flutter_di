import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  tearDown(() {
    RootScope.reset();
  });

  test('single put', () {
    final scope = DiScope.open('test_root');
    const source = 1;
    scope.put(source);
    expect(scope.contains<int>(), isTrue);
    final value = scope.find<int>();
    expect(value, source);
    scope.close();
  });

  test('scope notifies listeners after registration changes', () {
    final scope = DiScope.open('test_root');
    var notifications = 0;
    scope.addListener(() => notifications++);

    scope.put<int>(1);
    scope.replace<int>(2);
    scope.evict<int>();

    expect(notifications, 3);
    scope.close();
  });

  test('parent scope notifies listeners when child scope opens and closes', () {
    final parent = DiScope.open('test_root');
    var notifications = 0;
    parent.addListener(() => notifications++);

    final child = DiScope.open('child', knownParentScope: parent);
    child.close();

    expect(notifications, 2);
    parent.close();
  });

  test('untagged contains', () {
    final scope = DiScope.open('test_root');
    const source = 1;
    scope.put(source);
    expect(scope.contains<int>(), isTrue);
    scope.close();
  });

  test('tagged contains', () {
    final scope = DiScope.open('test_root');
    const source = 1;
    scope.put(source, tag: '1');
    expect(scope.contains<int>(tag: '1'), isTrue);
    scope.close();
  });

  test('untagged + tagged put', () {
    final scope = DiScope.open('test_root');
    const sourceA = 1;
    const sourceB = 2;
    scope.put(sourceA);
    scope.put(sourceB, tag: 'B');
    expect(scope.contains<int>(), isTrue);
    expect(scope.contains<int>(tag: 'B'), isTrue);
    final valueA = scope.find<int>();
    expect(valueA, sourceA);
    final valueB = scope.find<int>(tag: 'B');
    expect(valueB, sourceB);
    scope.close();
  });

  test('single put + evict', () {
    final scope = DiScope.open('test_root');
    const source = 1;
    scope.put(source);
    expect(scope.contains<int>(), isTrue);
    final value = scope.evict<int>();
    expect(value, source);
    expect(scope.contains<int>(), isFalse);
    scope.close();
  });

  test('multiscope, a+b', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    root.put<int>(1);
    child.put<double>(2.0);
    expect(child.contains<double>(), isTrue);
    expect(child.isRegistered<int>(), isTrue);
    final i = child.find<int>();
    final d = child.find<double>();
    expect(i, 1);
    expect(d, 2.0);
    root.close();
  });

  test('multiscope, substitute', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    root.put<int>(1);
    child.put<int>(2);
    expect(child.contains<int>(), isTrue);
    final i = child.find<int>();
    expect(i, 2);
    root.close();
  });

  test('evict', () {
    const a = 1;
    RootScope.replace<int>(a);
    const b = 2;
    RootScope.replace<int>(b);
    expect(RootScope.find<int>(), b);
  });

  test('evict with dispose', () {
    const a = 1;
    RootScope.replace<int>(
      a,
      onDispose: (p0) {},
    );
    const b = 2;
    RootScope.replace<int>(b, onDispose: (p0) {});
    expect(RootScope.find<int>(), b);
  });

  test('replace honors tag', () {
    final scope = DiScope.open('test_root');
    scope.put<int>(1);
    scope.replace<int>(2, tag: 'tagged');
    expect(scope.find<int>(), 1);
    expect(scope.find<int>(tag: 'tagged'), 2);
    scope.close();
  });

  test('isRegistered checks all ancestors', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    final grandChild = DiScope.open('grandChild', knownParentScope: child);
    root.put<int>(10);
    expect(grandChild.isRegistered<int>(), isTrue);
    root.close();
  });

  test('find by abstraction and implementation resolves same instance', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelAbstraction>(vm);

    final asAbstraction = scope.find<ViewModelAbstraction>();
    final asImplementation = scope.find<ViewModelImplementation>();

    expect(identical(asAbstraction, vm), isTrue);
    expect(identical(asImplementation, vm), isTrue);
    scope.close();
  });

  test('put can skip runtime type registration', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelAbstraction>(vm, registerRuntimeType: false);

    expect(scope.find<ViewModelAbstraction>(), same(vm));
    expect(() => scope.find<ViewModelImplementation>(),
        throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('replace can skip runtime type registration', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    scope.replace<ViewModelAbstraction>(vm, registerRuntimeType: false);

    expect(scope.find<ViewModelAbstraction>(), same(vm));
    expect(() => scope.find<ViewModelImplementation>(),
        throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('contains does not create a lazy registration', () {
    final scope = DiScope.open('test_root');
    var factoryCalls = 0;
    scope.putLazy<ViewModelAbstraction>(() {
      factoryCalls++;
      return ViewModelImplementation();
    });

    expect(scope.contains<ViewModelAbstraction>(), isTrue);
    expect(scope.isRegistered<ViewModelAbstraction>(), isTrue);
    expect(factoryCalls, 0);
    scope.close();
  });

  test('replaceLazy does not create an unused lazy registration', () {
    final scope = DiScope.open('test_root');
    var factoryCalls = 0;
    var disposed = false;
    scope.putLazy<ViewModelAbstraction>(
      () {
        factoryCalls++;
        return ViewModelImplementation();
      },
      onDispose: (_) => disposed = true,
    );
    final replacement = ViewModelImplementation();

    scope.replaceLazy<ViewModelAbstraction>(() => replacement);

    expect(factoryCalls, 0);
    expect(disposed, isFalse);
    expect(scope.find<ViewModelAbstraction>(), same(replacement));
    scope.close();
  });

  test('putLazyAs registers abstraction and implementation keys lazily', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    var factoryCalls = 0;
    scope.putLazyAs<ViewModelAbstraction, ViewModelImplementation>(() {
      factoryCalls++;
      return vm;
    });

    expect(scope.contains<ViewModelAbstraction>(), isTrue);
    expect(scope.contains<ViewModelImplementation>(), isTrue);
    expect(factoryCalls, 0);
    expect(scope.find<ViewModelImplementation>(), same(vm));
    expect(scope.find<ViewModelAbstraction>(), same(vm));
    expect(factoryCalls, 1);
    scope.close();
  });

  test('putLazyAs rejects an occupied implementation key', () {
    final scope = DiScope.open('test_root');
    var factoryCalls = 0;
    scope.putLazyAs<ViewModelAbstraction, ViewModelImplementation>(() {
      factoryCalls++;
      return ViewModelImplementation();
    });

    expect(
      () => scope.put<ViewModelImplementation>(ViewModelImplementation()),
      throwsA(isA<DuplicateInstanceException>()),
    );
    expect(factoryCalls, 0);
    scope.close();
  });

  test('replaceLazyAs replaces both explicit lazy keys', () {
    final scope = DiScope.open('test_root');
    var oldFactoryCalls = 0;
    final replacement = ViewModelImplementation();
    scope.putLazyAs<ViewModelAbstraction, ViewModelImplementation>(() {
      oldFactoryCalls++;
      return ViewModelImplementation();
    });

    scope.replaceLazyAs<ViewModelAbstraction, ViewModelImplementation>(
      () => replacement,
    );

    expect(oldFactoryCalls, 0);
    expect(scope.find<ViewModelAbstraction>(), same(replacement));
    expect(scope.find<ViewModelImplementation>(), same(replacement));
    scope.close();
  });

  test('find requires an explicitly registered abstraction key', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelImplementation>(vm, registerRuntimeType: false);

    expect(
      () => scope.find<ViewModelAbstraction>(),
      throwsA(isA<InstanceNotFoundException>()),
    );
    scope.close();
  });

  test('find resolves concrete alias registered with an abstraction', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelAbstraction>(vm);

    expect(scope.find<ViewModelAbstraction>(), same(vm));
    expect(scope.find<ViewModelImplementation>(), same(vm));
    scope.close();
  });

  test('find does not infer intermediate abstractions from a concrete alias',
      () {
    final scope = DiScope.open('test_root');
    final repo = ImplementationC();
    scope.put<ContractA>(repo);

    expect(scope.find<ContractA>(), same(repo));
    expect(scope.find<ImplementationC>(), same(repo));
    expect(
      () => scope.find<ContractB>(),
      throwsA(isA<InstanceNotFoundException>()),
    );
    scope.close();
  });

  test('concrete alias conflicts with an explicit concrete registration', () {
    final scope = DiScope.open('test_root');
    scope.put<ViewModelAbstraction>(ViewModelImplementation());

    expect(
      () => scope.put<ViewModelImplementation>(ViewModelImplementation()),
      throwsA(isA<DuplicateInstanceException>()),
    );
    scope.close();
  });

  test('duplicate scope names are rejected', () {
    final root = DiScope.open('test_root');
    DiScope.open('child', knownParentScope: root);
    expect(
      () => DiScope.open('child', knownParentScope: root),
      throwsA(isA<DuplicateScopeException>()),
    );
    root.close();
  });

  test('instance-not-found includes requested tag', () {
    final scope = DiScope.open('test_root');
    try {
      scope.find<int>(tag: 'x');
      fail('Expected InstanceNotFoundException');
    } on InstanceNotFoundException catch (ex) {
      expect(ex.tag, 'x');
      expect(ex.requestedType, int);
    }
    scope.close();
  });

  test('instance-not-found reports the scope where lookup started', () {
    final scope = DiScope.open('test_root');

    expect(
      () => scope.find<ViewModelAbstraction>(),
      throwsA(
        isA<InstanceNotFoundException>()
            .having((error) => error.scope, 'scope', same(scope)),
      ),
    );
    scope.close();
  });

  test('empty scope names are rejected', () {
    expect(() => DiScope.open(''), throwsArgumentError);
  });

  test('closed scopes cannot be used as parents', () {
    final parent = DiScope.open('test_root');
    parent.close();

    expect(
      () => DiScope.open('child', knownParentScope: parent),
      throwsStateError,
    );
  });

  test('RootScope cannot be closed directly', () {
    expect(RootScope.close, throwsArgumentError);
  });

  test('closed scopes cannot be reset', () {
    final scope = DiScope.open('test_root');
    scope.close();

    expect(scope.reset, throwsStateError);
  });

  test('reset disposes registrations and closes child scopes', () {
    final scope = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: scope);
    final localResource = DisposableResource();
    final childResource = DisposableResource();
    scope.put<DisposableResource>(
      localResource,
      onDispose: (resource) => resource.disposed = true,
    );
    child.put<DisposableResource>(
      childResource,
      onDispose: (resource) => resource.disposed = true,
    );

    scope.reset();

    expect(localResource.disposed, isTrue);
    expect(childResource.disposed, isTrue);
    expect(scope.locateScope('child'), isNull);
    expect(scope.contains<DisposableResource>(), isFalse);
    expect(scope.put<int>(1), 1);
    scope.close();
  });

  test('scope remains a valid hash set member after closing', () {
    final scope = DiScope.open('test_root');
    final scopes = <DiScope>{scope};

    scope.close();

    expect(scopes.contains(scope), isTrue);
  });

  test('evict by abstraction removes implementation alias', () {
    final scope = DiScope.open('test_root');
    scope.put<ViewModelAbstraction>(ViewModelImplementation());
    scope.evict<ViewModelAbstraction>();

    expect(() => scope.find<ViewModelImplementation>(),
        throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('evict by concrete alias removes abstraction registration', () {
    final scope = DiScope.open('test_root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelAbstraction>(vm);

    expect(scope.evict<ViewModelImplementation>(), same(vm));
    expect(
      () => scope.find<ViewModelAbstraction>(),
      throwsA(isA<InstanceNotFoundException>()),
    );
    scope.close();
  });

  test('findInChildren resolves unique child match', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    child.put<int>(42);

    expect(root.findInChildren<int>(), 42);
    root.close();
  });

  test('findInChildren requires an explicit type key', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    final vm = ViewModelImplementation();
    child.put<ViewModelImplementation>(vm,
        tag: 'vm', registerRuntimeType: false);

    expect(
      () => root.findInChildren<ViewModelAbstraction>(tag: 'vm'),
      throwsA(isA<InstanceNotFoundException>()),
    );
    expect(root.findInChildren<ViewModelImplementation>(tag: 'vm'), same(vm));
    root.close();
  });

  test('findInChildren throws when multiple children match', () {
    final root = DiScope.open('test_root');
    final childA = DiScope.open('childA', knownParentScope: root);
    final childB = DiScope.open('childB', knownParentScope: root);
    childA.put<int>(1);
    childB.put<int>(2);

    expect(
      () => root.findInChildren<int>(),
      throwsA(isA<MultipleInstancesFoundException>()),
    );
    root.close();
  });

  test('findInChildren resolves nested descendant match', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    final grandChild = DiScope.open('grandChild', knownParentScope: child);
    grandChild.put<int>(7);

    expect(root.findInChildren<int>(), 7);
    root.close();
  });

  test('findInChildren throws not found when descendants have no match', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    child.put<double>(1.5);

    expect(
      () => root.findInChildren<int>(),
      throwsA(isA<InstanceNotFoundException>()),
    );
    root.close();
  });

  test('findInChildren multiple match error contains matched scopes', () {
    final root = DiScope.open('test_root');
    final childA = DiScope.open('childA', knownParentScope: root);
    final childB = DiScope.open('childB', knownParentScope: root);
    childA.put<int>(1, tag: 'x');
    childB.put<int>(2, tag: 'x');

    try {
      root.findInChildren<int>(tag: 'x');
      fail('Expected MultipleInstancesFoundException');
    } on MultipleInstancesFoundException catch (ex) {
      expect(ex.requestedType, int);
      expect(ex.tag, 'x');
      expect(ex.matches.map((s) => s.name).toSet(), {'childA', 'childB'});
    }
    root.close();
  });

  test('findInChildren onMany resolves multiple matches', () {
    final root = DiScope.open('test_root');
    final childA = DiScope.open('childA', knownParentScope: root);
    final childB = DiScope.open('childB', knownParentScope: root);
    childA.put<int>(10, tag: 'x');
    childB.put<int>(20, tag: 'x');

    final resolved = root.findInChildren<int>(
      tag: 'x',
      onMany: (children) => children.reduce((a, b) => a > b ? a : b),
    );

    expect(resolved, 20);
    root.close();
  });

  test('find does not search child scopes by default', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    child.put<int>(1);

    expect(() => root.find<int>(), throwsA(isA<InstanceNotFoundException>()));
    root.close();
  });

  test('find can search child scopes with searchDescendants', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    child.put<int>(42);

    expect(root.find<int>(searchDescendants: true), 42);
    root.close();
  });

  test('find searchDescendants throws on multiple child matches', () {
    final root = DiScope.open('test_root');
    final childA = DiScope.open('childA', knownParentScope: root);
    final childB = DiScope.open('childB', knownParentScope: root);
    childA.put<int>(1);
    childB.put<int>(2);

    expect(
      () => root.find<int>(searchDescendants: true),
      throwsA(isA<MultipleInstancesFoundException>()),
    );
    root.close();
  });

  test('find searchDescendants can resolve multiple child matches via onMany',
      () {
    final root = DiScope.open('test_root');
    final childA = DiScope.open('childA', knownParentScope: root);
    final childB = DiScope.open('childB', knownParentScope: root);
    childA.put<int>(1);
    childB.put<int>(2);

    final resolved = root.find<int>(
      searchDescendants: true,
      onMany: (children) => children.first,
    );

    expect(resolved, 1);
    root.close();
  });

  test('locateScopes finds scopes by type and tag', () {
    final root = DiScope.open('test_root');
    final childA = DiScope.open('childA', knownParentScope: root);
    final childB = DiScope.open('childB', knownParentScope: root);
    root.put<int>(1, tag: 'shared');
    childA.put<int>(2, tag: 'shared');
    childB.put<double>(3.0, tag: 'shared');

    final byType = root.locateScopes<int>(tag: 'shared');
    final byTag = root.locateScopesByTag('shared');

    expect(byType.map((s) => s.name).toList(), ['test_root', 'childA']);
    expect(
        byTag.map((s) => s.name).toList(), ['test_root', 'childA', 'childB']);
    root.close();
  });

  test('locateScopes can exclude current scope', () {
    final root = DiScope.open('test_root');
    final child = DiScope.open('child', knownParentScope: root);
    root.put<int>(1);
    child.put<int>(2);

    final onlyChildren = root.locateScopes<int>(includeSelf: false);

    expect(onlyChildren.map((s) => s.name).toList(), ['child']);
    root.close();
  });

  test('close handles multiple subscopes', () {
    final root = DiScope.open('test_root');
    DiScope.open('childA', knownParentScope: root);
    DiScope.open('childB', knownParentScope: root);
    expect(() => root.close(), returnsNormally);
  });

  test('close disposes remaining registrations after a disposer fails', () {
    final scope = DiScope.open('test_root');
    final second = DisposableResource();
    scope.put<DisposableResource>(
      DisposableResource(),
      tag: 'first',
      onDispose: (_) => throw StateError('first disposer failed'),
    );
    scope.put<DisposableResource>(
      second,
      tag: 'second',
      onDispose: (resource) => resource.disposed = true,
    );

    expect(scope.close, throwsStateError);
    expect(second.disposed, isTrue);
    expect(() => scope.find<DisposableResource>(), throwsStateError);
  });

  test('close disposes sibling scopes after a child disposer fails', () {
    final root = DiScope.open('test_root');
    final failingChild = DiScope.open('failing_child', knownParentScope: root);
    final sibling = DiScope.open('sibling', knownParentScope: root);
    final rootResource = DisposableResource();
    final siblingResource = DisposableResource();
    root.put<DisposableResource>(
      rootResource,
      onDispose: (resource) => resource.disposed = true,
    );
    failingChild.put<DisposableResource>(
      DisposableResource(),
      onDispose: (_) => throw StateError('child disposer failed'),
    );
    sibling.put<DisposableResource>(
      siblingResource,
      onDispose: (resource) => resource.disposed = true,
    );

    expect(root.close, throwsStateError);
    expect(rootResource.disposed, isTrue);
    expect(siblingResource.disposed, isTrue);
  });

  test('DiElement diagnostics do not create lazy values', () {
    var factoryCalls = 0;
    final element = DiElement<ViewModelAbstraction>.lazy(
      instancer: () {
        factoryCalls++;
        return ViewModelImplementation();
      },
    );

    expect(element.toString(), contains('<lazy>'));
    expect(factoryCalls, 0);
  });
}

abstract interface class ViewModelAbstraction {}

class ViewModelImplementation implements ViewModelAbstraction {}

abstract interface class ContractA {}

abstract interface class ContractB implements ContractA {}

class ImplementationC implements ContractB {}

class DisposableResource {
  bool disposed = false;
}
