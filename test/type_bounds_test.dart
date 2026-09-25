import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  test('non-nullable registration keys work at runtime', () {
    final scope = DiScope.open('non_nullable_type_bound_control');
    scope.put<String>('value');

    expect(scope.find<String>(), 'value');
    scope.close();
  });

  test('nullable registration and lookup keys fail compilation', () async {
    final root = Directory.current;
    final fixtureRoot = Directory(
      '${root.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}nullable_type_bounds',
    );
    await fixtureRoot.create(recursive: true);
    final fixtureDirectory = await fixtureRoot.createTemp('nullable_compile_');
    final source = File(
      '${fixtureDirectory.path}${Platform.pathSeparator}nullable_failures.dart',
    );
    final dartExecutable = _resolveDartExecutable();
    expect(
      await File(dartExecutable).exists(),
      isTrue,
      reason: 'Dart CLI not found at $dartExecutable',
    );

    const invalidCalls = <String>[
      "scope.put<String?>(null);",
      "scope.putLazy<String?>(() => null);",
      "scope.replace<String?>(null);",
      "scope.find<String?>();",
      "scope.contains<String?>();",
      "scope.evict<String?>();",
      'String? value; scope.put(value);',
    ];

    try {
      await source.writeAsString('''
import 'package:simple_service_locator/simple_service_locator.dart';

void main() {
  final scope = DiScope.open('compile_case');
${invalidCalls.map((call) => '  $call').join('\n')}
}
''');

      final process = await Process.start(dartExecutable, [
        'analyze',
        source.path,
      ], workingDirectory: root.path);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      late final int exitCode;
      try {
        exitCode = await process.exitCode.timeout(const Duration(seconds: 30));
      } on TimeoutException {
        process.kill();
        await process.exitCode;
        fail(
          'Dart analyzer exceeded 30 seconds. Output: '
          '${await stdout}\n${await stderr}',
        );
      }
      final output = '${await stdout}\n${await stderr}';

      expect(exitCode, isNot(0), reason: output);
      expect(
        'type_argument_not_matching_bounds'.allMatches(output),
        hasLength(6),
        reason: output,
      );
      expect(
        output,
        anyOf(
          contains('could_not_infer'),
          contains('argument_type_not_assignable'),
        ),
        reason: output,
      );
    } finally {
      await fixtureDirectory.delete(recursive: true);
    }
  });
}

String _resolveDartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final executableName = Platform.isWindows ? 'dart.exe' : 'dart';
    return '$flutterRoot${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}cache'
        '${Platform.pathSeparator}dart-sdk'
        '${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}$executableName';
  }

  final resolvedExecutable = Platform.resolvedExecutable;
  final executableName = File(
    resolvedExecutable,
  ).uri.pathSegments.last.toLowerCase();
  if (executableName == 'dart' || executableName == 'dart.exe') {
    return resolvedExecutable;
  }

  throw StateError(
    'Cannot locate the Dart CLI. Run this test with FLUTTER_ROOT set.',
  );
}
