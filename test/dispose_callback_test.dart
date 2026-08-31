import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  tearDown(() {
    RootScope.reset();
  });

  test('close invokes the dispose callback of a registered instance', () {
    final root = DiScope.open('test_root');
    final item = TestClass('somedata');
    root.put<TestClass>(
      item,
      onDispose: (item) {
        item.disposed = true;
      },
    );

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
