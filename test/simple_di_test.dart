import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_di/flutter_di.dart';

void main() {
  tearDown(() {
    RootScope.reset();
  });

  test('single put', () {
    final scope = DiScope.open('root');
    const source = 1;
    scope.put(source);
    expect(scope.contains<int>(), isTrue);
    final value = scope.find<int>();
    expect(value, source);
    scope.close();
  });

  test('untagged contains', () {
    final scope = DiScope.open('root');
    const source = 1;
    scope.put(source);
    expect(scope.contains<int>(), isTrue);
    scope.close();
  });

  test('tagged contains', () {
    final scope = DiScope.open('root');
    const source = 1;
    scope.put(source, tag: '1');
    expect(scope.contains<int>(tag: '1'), isTrue);
    scope.close();
  });

  test('untagged + tagged put', () {
    final scope = DiScope.open('root');
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
    final scope = DiScope.open('root');
    const source = 1;
    scope.put(source);
    expect(scope.contains<int>(), isTrue);
    final value = scope.evict<int>();
    expect(value, source);
    expect(scope.contains<int>(), isFalse);
    scope.close();
  });

  test('multiscope, a+b', () {
    final root = DiScope.open('root');
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
    final root = DiScope.open('root');
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
    RootScope.replace<int>(b, onDispose: (p0) => null);
    expect(RootScope.find<int>(), b);
  });

  test('replace honors tag', () {
    final scope = DiScope.open('root');
    scope.put<int>(1);
    scope.replace<int>(2, tag: 'tagged');
    expect(scope.find<int>(), 1);
    expect(scope.find<int>(tag: 'tagged'), 2);
    scope.close();
  });

  test('isRegistered checks all ancestors', () {
    final root = DiScope.open('root');
    final child = DiScope.open('child', knownParentScope: root);
    final grandChild = DiScope.open('grandChild', knownParentScope: child);
    root.put<int>(10);
    expect(grandChild.isRegistered<int>(), isTrue);
    root.close();
  });

  test('find by abstraction and implementation resolves same instance', () {
    final scope = DiScope.open('root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelAbstraction>(vm);

    final asAbstraction = scope.find<ViewModelAbstraction>();
    final asImplementation = scope.find<ViewModelImplementation>();

    expect(identical(asAbstraction, vm), isTrue);
    expect(identical(asImplementation, vm), isTrue);
    scope.close();
  });

  test('put can skip runtime type registration', () {
    final scope = DiScope.open('root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelAbstraction>(vm, registerRuntimeType: false);

    expect(scope.find<ViewModelAbstraction>(), same(vm));
    expect(() => scope.find<ViewModelImplementation>(), throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('replace can skip runtime type registration', () {
    final scope = DiScope.open('root');
    final vm = ViewModelImplementation();
    scope.replace<ViewModelAbstraction>(vm, registerRuntimeType: false);

    expect(scope.find<ViewModelAbstraction>(), same(vm));
    expect(() => scope.find<ViewModelImplementation>(), throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('find resolves descendant when exact type is not required', () {
    final scope = DiScope.open('root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelImplementation>(vm, registerRuntimeType: false);

    expect(scope.find<ViewModelAbstraction>(), same(vm));
    scope.close();
  });

  test('find with exactTypeMatch does not resolve descendant', () {
    final scope = DiScope.open('root');
    final vm = ViewModelImplementation();
    scope.put<ViewModelImplementation>(vm, registerRuntimeType: false);

    expect(() => scope.find<ViewModelAbstraction>(exactTypeMatch: true), throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('duplicate scope names are rejected', () {
    final root = DiScope.open('root');
    DiScope.open('child', knownParentScope: root);
    expect(
      () => DiScope.open('child', knownParentScope: root),
      throwsA(isA<DuplicateScopeException>()),
    );
    root.close();
  });

  test('instance-not-found includes requested tag', () {
    final scope = DiScope.open('root');
    try {
      scope.find<int>(tag: 'x');
      fail('Expected InstanceNotFoundException');
    } on InstanceNotFoundException catch (ex) {
      expect(ex.tag, 'x');
      expect(ex.requestedType, int);
    }
    scope.close();
  });

  test('evict by abstraction removes implementation alias', () {
    final scope = DiScope.open('root');
    scope.put<ViewModelAbstraction>(ViewModelImplementation());
    scope.evict<ViewModelAbstraction>();

    expect(() => scope.find<ViewModelImplementation>(), throwsA(isA<InstanceNotFoundException>()));
    scope.close();
  });

  test('close handles multiple subscopes', () {
    final root = DiScope.open('root');
    DiScope.open('childA', knownParentScope: root);
    DiScope.open('childB', knownParentScope: root);
    expect(() => root.close(), returnsNormally);
  });
}

abstract interface class ViewModelAbstraction {}

class ViewModelImplementation implements ViewModelAbstraction {}
