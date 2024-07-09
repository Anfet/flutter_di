import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_di/flutter_di.dart';

void main() {
  test('a', () async {
    var root = DiScope.open('root');
    var item = TestClass('somedata');
    root.put<TestClass>(
      item,
      onDispose: (item) {
        item.disposed = true;
      },
    );

    // var evicted = root.evict<TestClass>();
    root.close();
    assert(item.disposed);
  });
}

class TestClass {
  final data;
  bool disposed = false;

  TestClass(this.data);

  @override
  String toString() {
    return 'TestClass{data: $data}';
  }
}
