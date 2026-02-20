import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  tearDown(() {
    RootScope.reset();
  });

  test('a', () async {
    final root = DiScope.open('root');
    final item = TestClass('somedata');
    root.put<TestClass>(
      item,
      onDispose: (item) {
        item.disposed = true;
      },
    );

    // var evicted = root.evict<TestClass>();
    root.close();
    expect(item.disposed, isTrue);
  });
}

class TestClass {
  final String data;
  bool disposed = false;

  TestClass(this.data);

  @override
  String toString() {
    return 'TestClass{data: $data}';
  }
}
