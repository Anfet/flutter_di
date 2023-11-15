import 'package:flutter_test/flutter_test.dart';
import 'package:siberian_di/siberian_di.dart';

void main() {
  test('single put', () {
    var scope = DiScope.open('root');
    int source = 1;
    scope.put(source);
    assert(scope.contains<int>());
    var value = scope.find<int>();
    assert(value == source);
  });

  test('untagged contains', () {
    var scope = DiScope.open('root');
    int source = 1;
    scope.put(source);
    assert(scope.contains<int>());
  });

  test('tagged contains', () {
    var scope = DiScope.open('root');
    int source = 1;
    scope.put(source, tag: '1');
    assert(scope.contains<int>(tag: '1'));
  });

  test('untagged + tagged put', () {
    var scope = DiScope.open('root');
    int sourceA = 1;
    int sourceB = 2;
    scope.put(sourceA);
    scope.put(sourceB, tag: 'B');
    assert(scope.contains<int>());
    assert(scope.contains<int>(tag: 'B'));
    var valueA = scope.find<int>();
    assert(valueA == sourceA);
    var valueB = scope.find<int>(tag: 'B');
    assert(valueB == sourceB);
    scope.verboseTree();
  });

  test('single put + evict', () {
    var scope = DiScope.open('root');
    int source = 1;
    scope.put(source);
    assert(scope.contains<int>());
    var value = scope.evict<int>();
    assert(value == source);
    assert(!scope.contains<int>());
  });

  test('multiscope, a+b', () {
    var root = DiScope.open('root');
    var child = DiScope.open('child', parent: root);
    root.put<int>(1);
    child.put<double>(2.0);
    assert(child.contains<double>());
    assert(child.isRegistered<int>());
    var i = child.find<int>();
    var d = child.find<double>();
    assert(i == 1);
    assert(d == 2.0);
    root.verboseTree();
  });

  test('multiscope, substitute', () {
    var root = DiScope.open('root');
    var child = DiScope.open('child', parent: root);
    root.put<int>(1);
    child.put<int>(2);
    assert(child.contains<int>());
    var i = child.find<int>();
    assert(i == 2);
    root.verboseTree();
  });
}
