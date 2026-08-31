import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:simple_service_locator/src/di_element.dart';
import 'package:simple_service_locator/src/exceptions.dart';
import 'package:simple_service_locator/src/failure_collector.dart';

const _kRootScope = 'RootScope';

/// The singleton root scope for the application.
///
/// All scopes are attached to this scope directly or indirectly.
// ignore: non_constant_identifier_names
final RootScope = DiScope._root();

/// A named dependency scope that supports hierarchical lookup.
///
/// Instances can be registered directly or lazily and resolved by type
/// (optionally with a [tag]). Child scopes can override registrations from
/// parent scopes.
///
/// Registration and lookup keys are non-nullable: every generic entry point is
/// bound as `T extends Object`, so `put<T?>(...)` and `find<T?>()` do not
/// compile. A missing dependency is therefore always an
/// [InstanceNotFoundException] rather than a silently resolved `null`. Model
/// "configured, but absent" with an explicit wrapper or sentinel value.
class DiScope extends ChangeNotifier {
  /// A human-readable unique scope name within a root scope tree.
  final String name;
  late final DiScope? _parent;
  final Map<Type, Map<String, DiElement<Object?>>> _instances = {};
  final List<DiScope> _subScopes = [];
  bool _isClosed = false;
  bool _isNotifying = false;

  DiScope._root()
      : name = _kRootScope,
        _parent = null;

  /// Opens a new scope and attaches it to a parent scope.
  ///
  /// Parent resolution order:
  /// 1. [knownParentScope] if provided.
  /// 2. Scope found from root by [lookupParentScope].
  /// 3. [RootScope] when neither is given.
  ///
  /// Throws:
  /// - [ArgumentError] when [name] is empty.
  /// - [ScopeNotFoundException] when [lookupParentScope] is a non-empty name
  ///   that does not resolve. A misspelled parent name is reported here
  ///   instead of silently attaching the scope to [RootScope], which would
  ///   surface much later as an unrelated [InstanceNotFoundException].
  /// - [DuplicateScopeException] if a scope with [name] already exists in the
  ///   same root tree.
  DiScope.open(
    this.name, {
    DiScope? knownParentScope,
    String? lookupParentScope,
  }) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'scope name must not be empty');
    }
    _parent = knownParentScope ??
        _resolveParentByName(lookupParentScope) ??
        RootScope;
    _parent!._assertOpen();
    final root = RootScope;
    if (root.locateScope(name) != null) {
      throw DuplicateScopeException(name, root);
    }
    _parent?._subScopes.add(this);
    // Notified after the scope is fully attached. Notifying earlier would let
    // a listener re-enter DiScope.open() while this constructor is still
    // running and observe a half-built tree.
    _parent?.notifyListeners();
  }

  /// Notifies listeners of a scope or registration change.
  ///
  /// Reentrant calls are suppressed: [ChangeNotifier] dispatches listeners
  /// synchronously, so a listener that itself mutates the scope (opens a child
  /// scope, registers a dependency) would otherwise re-enter the same listener
  /// before its first invocation returned, and observe partially applied
  /// state. The mutation still happens; only the nested notification is
  /// dropped, because the outer dispatch already reports the final state.
  @override
  void notifyListeners() {
    if (_isNotifying) {
      return;
    }

    _isNotifying = true;
    try {
      super.notifyListeners();
    } finally {
      _isNotifying = false;
    }
  }

  /// Resolves a parent scope from an explicit [name].
  ///
  /// Returns `null` when no name was supplied, so the caller can fall back to
  /// [RootScope]. A supplied but unknown name is an error rather than a
  /// fallback.
  static DiScope? _resolveParentByName(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    final parent = RootScope.locateScope(name);
    if (parent == null) {
      throw ScopeNotFoundException(name);
    }

    return parent;
  }

  /// Closes an existing scope by [name].
  ///
  /// Throws:
  /// - [ArgumentError] when attempting to close the root scope.
  /// - [ScopeNotFoundException] when the scope does not exist.
  static void closeScope(String name) {
    if (name == _kRootScope) {
      throw ArgumentError('cannot close root scope');
    }

    var scope = RootScope.locateScope(name);
    if (scope == null) {
      throw ScopeNotFoundException(name);
    }

    scope.close();
  }

  /// Finds a scope by [name] in this scope subtree.
  ///
  /// Returns `null` when [name] is `null`, empty, or not found.
  DiScope? locateScope(final String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    if (this.name == name) {
      return this;
    }

    for (var sub in _subScopes) {
      var subResult = sub.locateScope(name);
      if (subResult != null) {
        return subResult;
      }
    }

    return null;
  }

  DiElement<Object?>? _elementOf<T extends Object>(String? tag) =>
      _instances[T]?[tag ?? ''];

  DiElement<Object?>? _elementOfType(Type type, String? tag) =>
      _instances[type]?[tag ?? ''];

  /// Returns `true` when this scope has a registration for type `T`.
  ///
  /// This checks only the current scope, not ancestors.
  ///
  /// Throws [StateError] when this scope is closed: a closed scope holds no
  /// registrations, and answering `false` would be indistinguishable from a
  /// live scope that simply does not have `T`.
  bool contains<T extends Object>({String? tag}) {
    _assertOpen();
    return _elementOf<T>(tag) != null;
  }

  /// Returns `true` when this scope has a registration for [type].
  ///
  /// This checks only the current scope, not ancestors.
  ///
  /// Throws [StateError] when this scope is closed.
  bool containsType(Type type, {String? tag}) {
    _assertOpen();
    return _elementOfType(type, tag) != null;
  }

  /// Returns `true` when `T` is registered in this scope or any ancestor.
  ///
  /// Throws [StateError] when this scope is closed.
  bool isRegistered<T extends Object>({String? tag}) {
    _assertOpen();
    return _isRegistered<T>(tag: tag);
  }

  bool _isRegistered<T extends Object>({String? tag}) {
    if (_elementOf<T>(tag) != null) {
      return true;
    }

    return _parent?._isRegistered<T>(tag: tag) ?? false;
  }

  /// Returns `true` when [type] is registered in this scope or any ancestor.
  ///
  /// Throws [StateError] when this scope is closed.
  bool isRegisteredType(Type type, {String? tag}) {
    _assertOpen();
    return _isRegisteredType(type, tag: tag);
  }

  bool _isRegisteredType(Type type, {String? tag}) {
    if (_elementOfType(type, tag) != null) {
      return true;
    }

    return _parent?._isRegisteredType(type, tag: tag) ?? false;
  }

  /// Alias for [find].
  T call<T extends Object>({
    String? tag,
    bool searchDescendants = false,
    T Function(Iterable<T> children)? onMany,
  }) =>
      find<T>(
        tag: tag,
        searchDescendants: searchDescendants,
        onMany: onMany,
      );

  /// Resolves an instance of `T`.
  ///
  /// Lookup order:
  /// 1. Local registration by exact key `T`.
  /// 2. Parent scopes recursively.
  /// 3. Child scopes when [searchDescendants] is `true`.
  ///
  /// A direct registration using [put] creates keys for both its declared type
  /// and, by default, its concrete runtime type. No other assignable types are
  /// inferred during lookup.
  ///
  /// [onMany] resolves ambiguity between several matching descendant scopes,
  /// so it is meaningful only together with [searchDescendants]. Passing it
  /// alone is an assertion error in debug builds rather than a silently
  /// ignored argument.
  ///
  /// Throws [InstanceNotFoundException] when resolution fails.
  T find<T extends Object>({
    String? tag,
    bool searchDescendants = false,
    T Function(Iterable<T> children)? onMany,
  }) {
    assert(
      onMany == null || searchDescendants,
      'onMany only applies to descendant lookup; '
      'pass searchDescendants: true or drop onMany',
    );
    _assertOpen();

    // Ancestor chain lookup uses an explicit miss result instead of catching
    // [InstanceNotFoundException]. Catching would swallow the same exception
    // type thrown from inside a user lazy factory that failed to resolve its
    // own dependency, and report it as a miss of `T`.
    final selfOrAncestor = _findUpwards<T>(tag: tag);
    if (selfOrAncestor.found) {
      return selfOrAncestor.value as T;
    }

    if (searchDescendants) {
      final descendant = _findInChildrenOrMiss<T>(tag: tag, onMany: onMany);
      if (descendant.found) {
        return descendant.value as T;
      }
    }

    throw InstanceNotFoundException(T, this, tag: tag);
  }

  /// Resolves `T` in this scope and then in ancestors, without using
  /// exceptions to signal a miss.
  _Lookup _findUpwards<T extends Object>({String? tag}) {
    final local = _lookupLocal<T>(tag: tag);
    if (local.found) {
      return local;
    }

    return _parent?._findUpwards<T>(tag: tag) ?? const _Lookup.miss();
  }

  /// Resolves an instance of `T` only in descendant scopes.
  ///
  /// This does not search current scope or ancestors.
  ///
  /// Throws:
  /// - [InstanceNotFoundException] when no descendants match.
  /// - [MultipleInstancesFoundException] when more than one descendant matches.
  T findInChildren<T extends Object>({
    String? tag,
    T Function(Iterable<T> children)? onMany,
  }) {
    _assertOpen();
    final result = _findInChildrenOrMiss<T>(tag: tag, onMany: onMany);
    if (!result.found) {
      throw InstanceNotFoundException(T, this, tag: tag);
    }

    return result.value as T;
  }

  /// Descendant lookup that reports a miss as a result instead of throwing.
  ///
  /// [MultipleInstancesFoundException] and any error raised by a user lazy
  /// factory or by [onMany] still propagate; only "no match" is a result.
  _Lookup _findInChildrenOrMiss<T extends Object>({
    String? tag,
    T Function(Iterable<T> children)? onMany,
  }) {
    final matches = <_ScopedMatch<T>>[];
    final visited = <DiScope>{this};
    final queue = Queue<DiScope>.of(_subScopes);
    while (queue.isNotEmpty) {
      final scope = queue.removeFirst();
      if (!visited.add(scope)) {
        continue;
      }

      final local = scope._lookupLocal<T>(tag: tag);
      if (local.found) {
        matches.add(_ScopedMatch(scope: scope, value: local.value as T));
      }
      queue.addAll(scope._subScopes);
    }

    if (matches.isEmpty) {
      return const _Lookup.miss();
    }
    if (matches.length > 1) {
      if (onMany != null) {
        return _Lookup.hit(onMany(matches.map((m) => m.value)));
      }
      throw MultipleInstancesFoundException(
        T,
        this,
        tag: tag,
        matches: matches.map((m) => m.scope).toList(growable: false),
      );
    }

    return _Lookup.hit(matches.first.value);
  }

  /// Finds descendant scopes containing an explicit registration for `T` and
  /// [tag].
  ///
  /// Set [includeSelf] to include the current scope in the search.
  List<DiScope> locateScopes<T extends Object>({
    String? tag,
    bool includeSelf = true,
  }) {
    _assertOpen();
    final result = <DiScope>[];
    final visited = <DiScope>{};
    final queue = Queue<DiScope>();
    if (includeSelf) {
      queue.add(this);
    } else {
      queue.addAll(_subScopes);
    }

    while (queue.isNotEmpty) {
      final scope = queue.removeFirst();
      if (!visited.add(scope)) {
        continue;
      }

      // Key presence only: a scope-discovery query must not materialize
      // lazy registrations in the scopes it walks over.
      if (scope.contains<T>(tag: tag)) {
        result.add(scope);
      }
      queue.addAll(scope._subScopes);
    }

    return result;
  }

  /// Finds descendant scopes that have any local registration with [tag].
  ///
  /// Set [includeSelf] to include the current scope in the search.
  List<DiScope> locateScopesByTag(String tag, {bool includeSelf = true}) {
    _assertOpen();
    final result = <DiScope>[];
    final visited = <DiScope>{};
    final queue = Queue<DiScope>();
    if (includeSelf) {
      queue.add(this);
    } else {
      queue.addAll(_subScopes);
    }

    while (queue.isNotEmpty) {
      final scope = queue.removeFirst();
      if (!visited.add(scope)) {
        continue;
      }

      if (scope._containsTag(tag)) {
        result.add(scope);
      }
      queue.addAll(scope._subScopes);
    }

    return result;
  }

  /// Local lookup that distinguishes "not registered" from a registered
  /// value that happens to be `null`.
  _Lookup _lookupLocal<T extends Object>({String? tag}) {
    final element = _elementOf<T>(tag);
    if (element == null) {
      return const _Lookup.miss();
    }

    final instance = element.instance;
    return instance is T ? _Lookup.hit(instance) : const _Lookup.miss();
  }

  bool _containsTag(String tag) {
    for (final entries in _instances.values) {
      if (entries.containsKey(tag)) {
        return true;
      }
    }

    return false;
  }

  /// Asserts that [candidate] is free, or is only held by the registration
  /// that is about to be replaced.
  ///
  /// Used to validate every target key *before* a replace removes anything,
  /// so a rejected replace cannot destroy the previous registration.
  void _assertReplacementKeyAvailable<T extends Object>(
    Type candidate, {
    required String? tag,
  }) {
    if (candidate == T) {
      return;
    }

    final occupant = _elementOfType(candidate, tag);
    if (occupant == null) {
      return;
    }

    // Aliases of the registration being replaced are released by the replace
    // itself, so they do not conflict.
    if (identical(occupant, _elementOf<T>(tag))) {
      return;
    }

    throw DuplicateInstanceException(
      candidate,
      this,
      instanceType: candidate,
      tag: tag,
    );
  }

  /// Replaces an existing local registration for `T`.
  ///
  /// All target keys are validated before anything is removed: when the
  /// replacement conflicts with an unrelated registration, the call throws
  /// [DuplicateInstanceException] and the previous registration for `T` is
  /// left intact and undisposed.
  ///
  /// Otherwise the existing local value is evicted first (and disposed through
  /// its callback), then [instance] is registered via [put].
  T replace<T extends Object>(
    T instance, {
    String? tag,
    DisposeCallback<T>? onDispose,
    bool registerRuntimeType = true,
  }) {
    _assertOpen();
    if (registerRuntimeType) {
      _assertReplacementKeyAvailable<T>(instance.runtimeType, tag: tag);
    }
    if (contains<T>(tag: tag)) {
      _remove<T>(tag: tag).dispose();
    }

    return _put<T>(
      instance,
      tag: tag,
      onDispose: onDispose,
      registerRuntimeType: registerRuntimeType,
      notify: true,
    );
  }

  /// Replaces an existing lazy registration for `T` in this scope.
  ///
  /// If an instance exists for the same type/tag in this scope, it is evicted
  /// first and disposed via its callback.
  void replaceLazy<T extends Object>(ValueGetter<T> instancer,
      {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    if (contains<T>(tag: tag)) {
      _remove<T>(tag: tag).dispose();
    }

    _putLazy<T>(instancer, tag: tag, onDispose: onDispose);
    notifyListeners();
  }

  /// Replaces a lazy registration while keeping both declared and implementation
  /// type keys available for lookup.
  ///
  /// Both target keys are validated before anything is removed: when
  /// [TImplementation] is already held by an unrelated registration, the call
  /// throws [DuplicateInstanceException] and the previous registration for `T`
  /// is left intact and undisposed.
  void replaceLazyAs<T extends Object, TImplementation extends T>(
    ValueGetter<TImplementation> instancer, {
    String? tag,
    DisposeCallback<TImplementation>? onDispose,
  }) {
    _assertOpen();
    _assertReplacementKeyAvailable<T>(TImplementation, tag: tag);
    if (contains<T>(tag: tag)) {
      _remove<T>(tag: tag).dispose();
    }
    _putLazyAs<T, TImplementation>(
      instancer,
      tag: tag,
      onDispose: onDispose,
    );
    notifyListeners();
  }

  /// Registers `T` lazily in the current scope.
  ///
  /// The first read materializes the value and caches it.
  ///
  /// Throws [DuplicateInstanceException] when a same type/tag registration
  /// already exists in this scope.
  void putLazy<T extends Object>(ValueGetter<T> instancer,
      {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    var item = _elementOf<T>(tag);
    if (item != null) {
      throw DuplicateInstanceException(
        T,
        this,
        instanceType: T,
        tag: tag,
      );
    }

    _putLazy<T>(instancer, tag: tag, onDispose: onDispose);
    notifyListeners();
  }

  /// Registers a lazy instance under both `T` and [TImplementation].
  ///
  /// This makes both explicit keys available without materializing the factory.
  /// Throws [DuplicateInstanceException] when either key is already registered
  /// in this scope for the same [tag].
  void putLazyAs<T extends Object, TImplementation extends T>(
    ValueGetter<TImplementation> instancer, {
    String? tag,
    DisposeCallback<TImplementation>? onDispose,
  }) {
    _assertOpen();
    if (contains<T>(tag: tag)) {
      throw DuplicateInstanceException(
        T,
        this,
        instanceType: TImplementation,
        tag: tag,
      );
    }
    _assertLazyImplementationKeyAvailable<T, TImplementation>(tag: tag);
    _putLazyAs<T, TImplementation>(
      instancer,
      tag: tag,
      onDispose: onDispose,
    );
    notifyListeners();
  }

  /// Registers [instance] in the current scope.
  ///
  /// By default, registration is created for both `T` and
  /// `instance.runtimeType` when they differ. Set [registerRuntimeType] to
  /// `false` to only register under `T`.
  ///
  /// Throws [DuplicateInstanceException] when a conflicting registration with
  /// the same type/tag exists in this scope.
  T put<T extends Object>(
    T instance, {
    String? tag,
    DisposeCallback<T>? onDispose,
    bool registerRuntimeType = true,
  }) =>
      _put<T>(
        instance,
        tag: tag,
        onDispose: onDispose,
        registerRuntimeType: registerRuntimeType,
        notify: true,
      );

  T _put<T extends Object>(
    T instance, {
    String? tag,
    DisposeCallback<T>? onDispose,
    required bool registerRuntimeType,
    required bool notify,
  }) {
    _assertOpen();
    final tagKey = tag ?? '';
    if (contains<T>(tag: tag)) {
      throw DuplicateInstanceException(
        T,
        this,
        instanceType: instance.runtimeType,
        tag: tag,
      );
    }

    final runtimeType = instance.runtimeType;
    if (registerRuntimeType &&
        runtimeType != T &&
        containsType(runtimeType, tag: tag)) {
      throw DuplicateInstanceException(
        runtimeType,
        this,
        instanceType: runtimeType,
        tag: tag,
      );
    }

    final item = DiElement<Object?>.direct(
      item: instance,
      tag: tag,
      onDispose: onDispose == null ? null : (value) => onDispose(value as T),
    );
    _instances.putIfAbsent(T, () => <String, DiElement<Object?>>{})[tagKey] =
        item;
    if (registerRuntimeType && runtimeType != T) {
      _instances.putIfAbsent(
        runtimeType,
        () => <String, DiElement<Object?>>{},
      )[tagKey] = item;
    }
    if (notify) {
      notifyListeners();
    }
    return instance;
  }

  void _putLazy<T extends Object>(
    ValueGetter<T> instancer, {
    String? tag,
    DisposeCallback<T>? onDispose,
  }) {
    final map = _instances.putIfAbsent(T, () => <String, DiElement<Object?>>{});
    map[tag ?? ''] = DiElement<Object?>.lazy(
      instancer: instancer,
      tag: tag,
      onDispose: onDispose == null ? null : (value) => onDispose(value as T),
    );
  }

  void _assertLazyImplementationKeyAvailable<T extends Object,
      TImplementation extends T>({
    String? tag,
  }) {
    if (TImplementation != T && containsType(TImplementation, tag: tag)) {
      throw DuplicateInstanceException(
        TImplementation,
        this,
        instanceType: TImplementation,
        tag: tag,
      );
    }
  }

  void _putLazyAs<T extends Object, TImplementation extends T>(
    ValueGetter<TImplementation> instancer, {
    String? tag,
    DisposeCallback<TImplementation>? onDispose,
  }) {
    final item = DiElement<Object?>.lazy(
      instancer: instancer,
      tag: tag,
      onDispose: onDispose == null
          ? null
          : (value) => onDispose(value as TImplementation),
    );
    final tagKey = tag ?? '';
    _instances.putIfAbsent(T, () => <String, DiElement<Object?>>{})[tagKey] =
        item;
    if (TImplementation != T) {
      _instances.putIfAbsent(
        TImplementation,
        () => <String, DiElement<Object?>>{},
      )[tagKey] = item;
    }
  }

  /// Disposes local registrations and closes all child scopes.
  ///
  /// This scope remains open and can be reused after the reset. Intended for
  /// tests and diagnostics.
  void reset() {
    _assertOpen();
    final failures = FailureCollector();
    _disposeContents(failures);
    failures.run(notifyListeners);
    failures.rethrowIfPresent();
  }

  /// Closes this scope, all descendants, and disposes owned instances.
  ///
  /// Safe to call multiple times. Safe to call from a listener of this scope
  /// or of its parent.
  void close() {
    if (identical(this, RootScope)) {
      throw ArgumentError('cannot close root scope');
    }
    if (_isClosed) {
      return;
    }

    _isClosed = true;
    final failures = FailureCollector();
    _parent?._subScopes.remove(this);
    failures.run(() => _parent?.notifyListeners());
    _disposeContents(failures);
    // No self-notification here: this scope is already closed, so a listener
    // could not act on it, and `ChangeNotifier.dispose()` asserts when it runs
    // inside a notification dispatch — which is exactly what happens when
    // close() is called from this scope's own listener.
    failures.run(super.dispose);
    failures.rethrowIfPresent();
  }

  /// Removes and returns a local instance registered for type `T`.
  ///
  /// Also removes aliases pointing to the same [DiElement] (for example runtime
  /// type registrations).
  ///
  /// Throws [InstanceNotFoundException] when no local registration exists.
  T evict<T extends Object>({String? tag}) {
    _assertOpen();
    final value = _evict<T>(tag: tag);
    notifyListeners();
    return value;
  }

  T _evict<T extends Object>({String? tag}) {
    final item = _remove<T>(tag: tag);
    final value = item.instance;
    item.onDispose?.call(value);
    return value as T;
  }

  DiElement<Object?> _remove<T extends Object>({String? tag}) {
    final tagKey = tag ?? '';
    final item = _instances[T]?[tagKey];
    if (item == null) {
      throw InstanceNotFoundException(T, this, tag: tag);
    }

    final emptyTypes = <Type>[];
    for (final entry in _instances.entries) {
      entry.value.removeWhere((_, value) => identical(value, item));
      if (entry.value.isEmpty) {
        emptyTypes.add(entry.key);
      }
    }
    for (final type in emptyTypes) {
      _instances.remove(type);
    }

    return item;
  }

  void _disposeContents(FailureCollector failures) {
    for (final scope in List<DiScope>.from(_subScopes)) {
      failures.run(scope.close);
    }

    final items = Set<DiElement<Object?>>.identity()
      ..addAll(_instances.values.expand((element) => element.values));
    for (final item in items) {
      failures.run(item.dispose);
    }

    _instances.clear();
    _subScopes.clear();
  }

  void _assertOpen() {
    if (_isClosed) {
      throw StateError("scope '$name' already closed");
    }
  }

  @override
  String toString() {
    // Deliberately shallow: printing parent and child scopes recursively made
    // a single scope dump the whole tree from both directions. Use
    // [verboseTree] for a full picture.
    final children = _subScopes.map((scope) => scope.name).join(', ');
    return 'DiScope{name: $name, parent: ${_parent?.name}, '
        'registrations: ${_instances.length}, subScopes: [$children], '
        'isClosed: $_isClosed}';
  }

  /// Prints a human-readable tree of scopes and instances using [debugPrint].
  ///
  /// Set [verboseInstances] to `false` to print only scope names.
  ///
  /// Lazy registrations are reported as `<lazy>`; their factories are not
  /// invoked.
  void verboseTree({
    @Deprecated(
      'Misspelled parameter kept for backward compatibility. '
      'Use verboseInstances instead. Will be removed in 1.0.0.',
    )
    bool verboseInstaces = true,
    bool? verboseInstances,
    String? offset,
  }) {
    // ignore: deprecated_member_use_from_same_package
    final shouldPrintInstances = verboseInstances ?? verboseInstaces;
    var tabs = offset ?? '';
    debugPrint("$tabs$name");
    if (shouldPrintInstances) {
      tabs += '\t';
      final printed = Set<DiElement<Object?>>.identity();
      for (final entry in _instances.entries) {
        for (final element in entry.value.values) {
          if (!printed.add(element)) {
            continue;
          }

          // Diagnostics must not materialize lazy factories: report the
          // registration key and materialization state, never `instance`.
          final type = entry.key;
          final isReplaced =
              _parent?._isRegisteredType(type, tag: element.tag) ?? false;
          final value = element.isMaterialized ? '${element.peek}' : '<lazy>';
          debugPrint(
              "$tabs<$type> $value; ${element.tag == null ? '' : '(${element.tag})'}${isReplaced ? ' overrides (${_parent?.name});' : ''}");
        }
      }
    }

    for (var s in _subScopes) {
      s.verboseTree(verboseInstances: shouldPrintInstances, offset: tabs);
    }
  }
}

/// Result of an internal lookup: either a hit carrying a (possibly `null`)
/// value, or a miss. Keeping these distinct avoids using exceptions as
/// control flow and lets `null` be a legitimate registered value.
class _Lookup {
  final bool found;
  final Object? value;

  const _Lookup.hit(this.value) : found = true;

  const _Lookup.miss()
      : found = false,
        value = null;
}

class _ScopedMatch<T> {
  final DiScope scope;
  final T value;

  _ScopedMatch({required this.scope, required this.value});
}
