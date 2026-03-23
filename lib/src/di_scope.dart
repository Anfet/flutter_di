import 'package:flutter/foundation.dart';
import 'package:simple_service_locator/src/exceptions.dart';

/// Called when an instance is removed from a scope or a scope is closed.
typedef DisposeCallback<T> = void Function(T);

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
class DiScope {
  /// A human-readable unique scope name within a root scope tree.
  final String name;
  late final DiScope? _parent;
  final Map<Type, Map<String, DiElement>> _instances = {};
  final List<DiScope> _subScopes = [];
  bool _isClosed = false;

  DiScope._root()
      : name = _kRootScope,
        _parent = null;

  /// Opens a new scope and attaches it to a parent scope.
  ///
  /// Parent resolution order:
  /// 1. [knownParentScope] if provided.
  /// 2. Scope found from root by [lookupParentScope].
  /// 3. [RootScope] as fallback.
  ///
  /// Throws [DuplicateScopeException] if a scope with [name] already exists
  /// in the same root tree.
  DiScope.open(
    this.name, {
    DiScope? knownParentScope,
    String? lookupParentScope,
  }) {
    _parent = knownParentScope ??
        RootScope.locateScope(lookupParentScope) ??
        RootScope;
    final root = RootScope;
    if (root.locateScope(name) != null) {
      throw DuplicateScopeException(name, root);
    }
    _parent?._subScopes.add(this);
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

  DiElement? _elementOf<T>(String? tag) => _instances[T]?[tag ?? ''];

  DiElement? _elementOfType(Type type, String? tag) =>
      _instances[type]?[tag ?? ''];

  /// Returns `true` when this scope has a registration for type `T`.
  ///
  /// This checks only the current scope, not ancestors.
  bool contains<T>({String? tag}) {
    final item = _elementOf<T>(tag);
    return item != null && item.instance is T;
  }

  /// Returns `true` when this scope has a registration for [type].
  ///
  /// This checks only the current scope, not ancestors.
  bool containsType(Type type, {String? tag}) =>
      _elementOfType(type, tag) != null;

  /// Returns `true` when `T` is registered in this scope or any ancestor.
  bool isRegistered<T>({String? tag}) {
    if (contains<T>(tag: tag)) {
      return true;
    }

    return _parent?.isRegistered<T>(tag: tag) ?? false;
  }

  /// Returns `true` when [type] is registered in this scope or any ancestor.
  bool isRegisteredType(Type type, {String? tag}) {
    if (containsType(type, tag: tag)) {
      return true;
    }

    return _parent?.isRegisteredType(type, tag: tag) ?? false;
  }

  /// Alias for [find].
  T call<T>({
    String? tag,
    bool exactTypeMatch = false,
    bool searchDescendants = false,
    T Function(Iterable<T> children)? onMany,
  }) =>
      find<T>(
        tag: tag,
        exactTypeMatch: exactTypeMatch,
        searchDescendants: searchDescendants,
        onMany: onMany,
      );

  /// Resolves an instance of `T`.
  ///
  /// Lookup order:
  /// 1. Local registration by exact key `T`.
  /// 2. Local descendant registration where runtime type is assignable to `T`
  ///    (skipped when [exactTypeMatch] is `true`).
  /// 3. Parent scopes recursively.
  /// 4. Child scopes when [searchDescendants] is `true`.
  ///
  /// Throws [InstanceNotFoundException] when resolution fails.
  T find<T>({
    String? tag,
    bool exactTypeMatch = false,
    bool searchDescendants = false,
    T Function(Iterable<T> children)? onMany,
  }) {
    _assertOpen();

    final local = _findLocal<T>(tag: tag, exactTypeMatch: exactTypeMatch);
    if (local != null) {
      return local;
    }

    InstanceNotFoundException? parentMiss;
    T? parent;
    try {
      parent = _parent?.find<T>(
        tag: tag,
        exactTypeMatch: exactTypeMatch,
        searchDescendants: false,
      );
    } on InstanceNotFoundException catch (ex) {
      parentMiss = ex;
    }
    if (parent != null) {
      return parent;
    }

    if (searchDescendants) {
      try {
        return findInChildren<T>(
          tag: tag,
          exactTypeMatch: exactTypeMatch,
          onMany: onMany,
        );
      } on InstanceNotFoundException {
        if (parentMiss != null) {
          throw parentMiss;
        }
      }
    }

    if (parentMiss != null) {
      throw parentMiss;
    }

    throw InstanceNotFoundException(T, this, tag: tag);
  }

  /// Resolves an instance of `T` only in descendant scopes.
  ///
  /// This does not search current scope or ancestors.
  ///
  /// Throws:
  /// - [InstanceNotFoundException] when no descendants match.
  /// - [MultipleInstancesFoundException] when more than one descendant matches.
  T findInChildren<T>({
    String? tag,
    bool exactTypeMatch = false,
    T Function(Iterable<T> children)? onMany,
  }) {
    _assertOpen();
    final matches = <_ScopedMatch<T>>[];
    final visited = <DiScope>{this};
    final queue = List<DiScope>.from(_subScopes);
    while (queue.isNotEmpty) {
      final scope = queue.removeAt(0);
      if (!visited.add(scope)) {
        continue;
      }

      final value =
          scope._findLocal<T>(tag: tag, exactTypeMatch: exactTypeMatch);
      if (value != null) {
        matches.add(_ScopedMatch(scope: scope, value: value));
      }
      queue.addAll(scope._subScopes);
    }

    if (matches.isEmpty) {
      throw InstanceNotFoundException(T, this, tag: tag);
    }
    if (matches.length > 1) {
      if (onMany != null) {
        return onMany(matches.map((m) => m.value));
      }
      throw MultipleInstancesFoundException(
        T,
        this,
        tag: tag,
        matches: matches.map((m) => m.scope).toList(growable: false),
      );
    }

    return matches.first.value;
  }

  /// Finds descendant scopes containing a registration matching `T` and [tag].
  ///
  /// Set [includeSelf] to include the current scope in the search.
  List<DiScope> locateScopes<T>({
    String? tag,
    bool exactTypeMatch = false,
    bool includeSelf = true,
  }) {
    _assertOpen();
    final result = <DiScope>[];
    final visited = <DiScope>{};
    final queue = <DiScope>[];
    if (includeSelf) {
      queue.add(this);
    } else {
      queue.addAll(_subScopes);
    }

    while (queue.isNotEmpty) {
      final scope = queue.removeAt(0);
      if (!visited.add(scope)) {
        continue;
      }

      if (scope._findLocal<T>(tag: tag, exactTypeMatch: exactTypeMatch) !=
          null) {
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
    final queue = <DiScope>[];
    if (includeSelf) {
      queue.add(this);
    } else {
      queue.addAll(_subScopes);
    }

    while (queue.isNotEmpty) {
      final scope = queue.removeAt(0);
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

  T? _findLocal<T>({String? tag, required bool exactTypeMatch}) {
    final element = _elementOf<T>(tag);
    if (element != null && element.instance is T) {
      return element.instance as T;
    }

    if (!exactTypeMatch) {
      return _findDescendant<T>(tag);
    }

    return null;
  }

  T? _findDescendant<T>(String? tag) {
    final tagKey = tag ?? '';
    final checked = Set<DiElement>.identity();
    for (final entry in _instances.entries) {
      final item = entry.value[tagKey];
      if (item == null) {
        continue;
      }

      // Consider only concrete runtime registrations when resolving descendants.
      if (entry.key != item.instance.runtimeType) {
        continue;
      }

      if (!checked.add(item)) {
        continue;
      }

      if (item.instance is T) {
        return item.instance as T;
      }
    }

    return null;
  }

  bool _containsTag(String tag) {
    for (final entries in _instances.values) {
      if (entries.containsKey(tag)) {
        return true;
      }
    }

    return false;
  }

  /// Replaces an existing local registration for `T`.
  ///
  /// Existing local value is evicted first (and disposed through callback),
  /// then [instance] is registered via [put].
  T replace<T>(
    T instance, {
    String? tag,
    DisposeCallback<T>? onDispose,
    bool registerRuntimeType = true,
  }) {
    _assertOpen();
    if (contains<T>(tag: tag)) {
      evict<T>(tag: tag);
    }

    return put<T>(
      instance,
      tag: tag,
      onDispose: onDispose,
      registerRuntimeType: registerRuntimeType,
    );
  }

  /// Replaces an existing lazy registration for `T` in this scope.
  ///
  /// If an instance exists for the same type/tag in this scope, it is evicted
  /// first and disposed via its callback.
  void replaceLazy<T>(ValueGetter<T> instancer,
      {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    if (contains<T>(tag: tag)) {
      evict<T>(tag: tag);
    }

    return putLazy<T>(instancer, tag: tag, onDispose: onDispose);
  }

  /// Registers `T` lazily in the current scope.
  ///
  /// The first read materializes the value and caches it.
  ///
  /// Throws [DuplicateInstanceException] when a same type/tag registration
  /// already exists in this scope.
  void putLazy<T>(ValueGetter<T> instancer,
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

    var map = _instances.putIfAbsent(T, () => <String, DiElement<T>>{});
    map[tag ?? ''] =
        DiElement<T>.lazy(instancer: instancer, tag: tag, onDispose: onDispose);
  }

  /// Registers [instance] in the current scope.
  ///
  /// By default, registration is created for both `T` and
  /// `instance.runtimeType` when they differ. Set [registerRuntimeType] to
  /// `false` to only register under `T`.
  ///
  /// Throws [DuplicateInstanceException] when a conflicting registration with
  /// the same type/tag exists in this scope.
  T put<T>(
    T instance, {
    String? tag,
    DisposeCallback<T>? onDispose,
    bool registerRuntimeType = true,
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

    final item =
        DiElement<T>.direct(item: instance, tag: tag, onDispose: onDispose);
    _instances.putIfAbsent(T, () => <String, DiElement>{})[tagKey] = item;
    if (registerRuntimeType && runtimeType != T) {
      _instances.putIfAbsent(runtimeType, () => <String, DiElement>{})[tagKey] =
          item;
    }
    return instance;
  }

  /// Clears all instances and child scopes without disposing anything.
  ///
  /// Intended for tests and diagnostics.
  void reset() {
    _isClosed = false;
    _instances.clear();
    _subScopes.clear();
  }

  /// Closes this scope, all descendants, and disposes owned instances.
  ///
  /// Safe to call multiple times.
  void close() {
    if (!_isClosed) {
      _isClosed = true;
      _parent?._subScopes.remove(this);

      for (var s in List<DiScope>.from(_subScopes)) {
        s.close();
      }

      final items = Set<DiElement>.identity()
        ..addAll(_instances.values.expand((element) => element.values));
      for (var item in items) {
        item.dispose();
      }

      _instances.clear();
      _subScopes.clear();
    }
  }

  /// Removes and returns a local instance registered for type `T`.
  ///
  /// Also removes aliases pointing to the same [DiElement] (for example runtime
  /// type registrations).
  ///
  /// Throws [InstanceNotFoundException] when no local registration exists.
  T evict<T>({String? tag}) {
    _assertOpen();
    final tagKey = tag ?? '';
    final item = _instances[T]?[tagKey] as DiElement<T>?;
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

    item.onDispose?.call(item.instance);
    return item.instance;
  }

  void _assertOpen() {
    if (_isClosed) {
      throw StateError("scope '$name' already closed");
    }
  }

  @override
  String toString() {
    return 'DiScope{name: $name, _parent: $_parent, _instances: $_instances, _subScopes: $_subScopes, _isClosed: $_isClosed}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiScope &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          _parent == other._parent &&
          _instances == other._instances &&
          _subScopes == other._subScopes &&
          _isClosed == other._isClosed;

  @override
  int get hashCode =>
      name.hashCode ^
      _parent.hashCode ^
      _instances.hashCode ^
      _subScopes.hashCode ^
      _isClosed.hashCode;

  /// Prints a human-readable tree of scopes and instances using [debugPrint].
  ///
  /// Set [verboseInstances] to `false` to print only scope names.
  ///
  /// [verboseInstaces] is kept for backward compatibility.
  void verboseTree({
    bool verboseInstaces = true,
    bool? verboseInstances,
    String? offset,
  }) {
    final shouldPrintInstances = verboseInstances ?? verboseInstaces;
    var tabs = offset ?? '';
    var items = _instances.values.expand((element) => element.values);
    debugPrint("$tabs$name");
    if (shouldPrintInstances) {
      tabs += '\t';
      for (var i in items) {
        var isReplaced =
            _parent?.isRegisteredType(i.instance.runtimeType, tag: i.tag) ??
                false;
        debugPrint(
            "$tabs<${i.instance.runtimeType}> ${i.instance}; ${i.tag == null ? '' : '(${i.tag})'}${isReplaced ? ' overrides (${_parent?.name});' : ''}");
      }
    }

    for (var s in _subScopes) {
      s.verboseTree(verboseInstaces: verboseInstaces, offset: tabs);
    }
  }
}

class _ScopedMatch<T> {
  final DiScope scope;
  final T value;

  _ScopedMatch({required this.scope, required this.value});
}

/// A wrapper around a direct or lazily created scoped instance.
class DiElement<T> {
  T? _instance;

  /// Lazily creates the element value when [instance] is first accessed.
  final ValueGetter<T>? instancer;

  /// Optional tag associated with this registration.
  final String? tag;

  /// Optional callback invoked when the element is disposed or evicted.
  final DisposeCallback<T>? onDispose;

  /// Returns the underlying instance, creating it lazily when needed.
  ///
  /// Throws [StateError] when the lazy factory returns `null`.
  T get instance {
    _instance ??= instancer?.call();
    final value = _instance;
    if (value == null) {
      throw StateError('DiElement instance is null');
    }
    return value;
  }

  /// Creates an element holding an already constructed [item].
  DiElement.direct({
    required T item,
    this.tag,
    this.onDispose,
  })  : _instance = item,
        instancer = null;

  /// Creates an element backed by a lazy [instancer] callback.
  DiElement.lazy({
    required this.instancer,
    this.tag,
    this.onDispose,
  }) : _instance = null;

  /// Disposes the current materialized instance if present.
  void dispose() {
    final value = _instance;
    if (value != null) {
      onDispose?.call(value);
    }
  }

  @override
  String toString() {
    return 'DiElement{instance: $instance, tag: $tag, onDispose: $onDispose}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiElement &&
          runtimeType == other.runtimeType &&
          instance == other.instance &&
          tag == other.tag &&
          onDispose == other.onDispose;

  @override
  int get hashCode => instance.hashCode ^ tag.hashCode ^ onDispose.hashCode;
}
