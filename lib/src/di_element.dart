import 'package:flutter/foundation.dart';

/// Called when an instance is removed from a scope or a scope is closed.
typedef DisposeCallback<T> = void Function(T);

class DiElement<T> {
  T? _instance;

  /// Whether [_instance] holds a real value.
  ///
  /// Tracked explicitly rather than inferred from `_instance != null`, so that
  /// a lazy factory which throws leaves the element unmaterialized and
  /// retryable, and an unused lazy registration is never materialized just to
  /// be disposed.
  bool _isMaterialized;

  /// Lazily creates the element value when [instance] is first accessed.
  final ValueGetter<T>? instancer;

  /// Optional tag associated with this registration.
  final String? tag;

  /// Optional callback invoked when the element is disposed or evicted.
  final DisposeCallback<T>? onDispose;

  /// Whether this element already holds a value.
  ///
  /// `false` for a lazy registration whose factory has not run yet.
  bool get isMaterialized => _isMaterialized;

  /// Returns the current value without ever running the lazy factory.
  ///
  /// Returns `null` when the element is not materialized yet. Intended for
  /// diagnostics; use [instance] to resolve a value.
  T? get peek => _instance;

  /// Returns the underlying instance, creating it lazily when needed.
  T get instance {
    if (!_isMaterialized) {
      final factory = instancer;
      if (factory == null) {
        throw StateError('DiElement has no value and no factory');
      }

      // Assign only after the factory returns, so a throwing factory leaves
      // the element unmaterialized and retryable.
      final created = factory();
      _instance = created;
      _isMaterialized = true;
      return created;
    }

    return _instance as T;
  }

  /// Creates an element holding an already constructed [item].
  DiElement.direct({
    required T item,
    this.tag,
    this.onDispose,
  })  : _instance = item,
        _isMaterialized = true,
        instancer = null;

  /// Creates an element backed by a lazy [instancer] callback.
  DiElement.lazy({
    required this.instancer,
    this.tag,
    this.onDispose,
  })  : _instance = null,
        _isMaterialized = false;

  /// Disposes the current materialized instance if present.
  ///
  /// An unused lazy registration is never materialized just to dispose it.
  void dispose() {
    if (_isMaterialized) {
      onDispose?.call(_instance as T);
    }
  }

  @override
  String toString() {
    return 'DiElement{instance: ${_isMaterialized ? _instance : '<lazy>'}, tag: $tag, onDispose: $onDispose}';
  }
}
