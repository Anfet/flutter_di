import 'package:simple_service_locator/simple_service_locator.dart';
import 'package:flutter/foundation.dart';

abstract interface class Logger {
  void log(String message);
}

class ConsoleLogger implements Logger {
  @override
  void log(String message) {
    debugPrint(message);
  }
}

void main() {
  RootScope.put<Logger>(ConsoleLogger());

  final logger = RootScope.find<Logger>();
  logger.log('simple_service_locator example is running');

  RootScope.reset();
}
