/// Internal helper. Not exported from `simple_service_locator.dart`.
///
/// Runs a sequence of cleanup actions, remembering the first failure.
///
/// Used by scope teardown so that one failing disposer cannot prevent the
/// remaining registrations and descendant scopes from being cleaned up. The
/// first error is rethrown once everything else has run.
class FailureCollector {
  Object? _error;
  StackTrace? _stackTrace;

  void run(void Function() action) {
    try {
      action();
    } catch (error, stackTrace) {
      _error ??= error;
      _stackTrace ??= stackTrace;
    }
  }

  void rethrowIfPresent() {
    final error = _error;
    final stackTrace = _stackTrace;
    if (error != null && stackTrace != null) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// A wrapper around a direct or lazily created scoped instance.
