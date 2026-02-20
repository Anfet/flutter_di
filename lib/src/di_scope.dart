import 'package:flutter/foundation.dart';
import 'package:flutter_di/src/exceptions.dart';

typedef DisposeCallback<T> = void Function(T);

const _kRootScope = 'RootScope';

// ignore: non_constant_identifier_names
final RootScope = DiScope._root();

class DiScope {
  final String name;
  late final DiScope? _parent;
  final Map<Type, Map<String, DiElement>> _instances = {};
  final List<DiScope> _subScopes = [];
  bool _isClosed = false;

  DiScope._root()
      : name = _kRootScope,
        _parent = null;

  DiScope.open(
    this.name, {
    DiScope? knownParentScope,
    String? lookupParentScope,
  }) {
    _parent = knownParentScope ?? RootScope.locateScope(lookupParentScope) ?? RootScope;
    final root = _parent?._rootScope() ?? this;
    if (root.locateScope(name) != null) {
      throw DuplicateScopeException(name, root);
    }
    _parent?._subScopes.add(this);
  }

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

  DiElement? _elementOfType(Type type, String? tag) => _instances[type]?[tag ?? ''];

  bool contains<T>({String? tag}) {
    final item = _elementOf<T>(tag);
    return item != null && item.instance is T;
  }

  bool containsType(Type type, {String? tag}) => _elementOfType(type, tag) != null;

  bool isRegistered<T>({String? tag}) {
    if (contains<T>(tag: tag)) {
      return true;
    }

    return _parent?.isRegistered<T>(tag: tag) ?? false;
  }

  bool isRegisteredType(Type type, {String? tag}) {
    if (containsType(type, tag: tag)) {
      return true;
    }

    return _parent?.isRegisteredType(type, tag: tag) ?? false;
  }

  T call<T>({String? tag, bool exactTypeMatch = false}) => find<T>(tag: tag, exactTypeMatch: exactTypeMatch);

  DiScope _rootScope() {
    DiScope current = this;
    while (current._parent != null) {
      current = current._parent!;
    }

    return current;
  }

  T find<T>({String? tag, bool exactTypeMatch = false}) {
    _assertOpen();

    final element = _elementOf<T>(tag);
    if (element != null && element.instance is T) {
      return element.instance as T;
    }

    if (!exactTypeMatch) {
      final localDescendant = _findDescendant<T>(tag);
      if (localDescendant != null) {
        return localDescendant;
      }
    }

    final parent = _parent?.find<T>(tag: tag, exactTypeMatch: exactTypeMatch);
    if (parent == null) {
      throw InstanceNotFoundException(T, this, tag: tag);
    }

    return parent;
  }

  T? _findDescendant<T>(String? tag) {
    final tagKey = tag ?? '';
    final checked = Set<DiElement>.identity();
    for (final entry in _instances.entries) {
      final item = entry.value[tagKey];
      if (item == null || !checked.add(item)) {
        continue;
      }

      // Consider only concrete runtime registrations when resolving descendants.
      if (entry.key != item.instance.runtimeType) {
        continue;
      }

      if (item.instance is T) {
        return item.instance as T;
      }
    }

    return null;
  }

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

  void replaceLazy<T>(ValueGetter<T> instancer, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    if (contains<T>(tag: tag)) {
      evict<T>(tag: tag);
    }

    return putLazy<T>(instancer, tag: tag, onDispose: onDispose);
  }

  void putLazy<T>(ValueGetter<T> instancer, {String? tag, DisposeCallback<T>? onDispose}) {
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
    map[tag ?? ''] = DiElement<T>.lazy(instancer: instancer, tag: tag, onDispose: onDispose);
  }

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
    if (registerRuntimeType && runtimeType != T && containsType(runtimeType, tag: tag)) {
      throw DuplicateInstanceException(
        runtimeType,
        this,
        instanceType: runtimeType,
        tag: tag,
      );
    }

    final item = DiElement<T>.direct(item: instance, tag: tag, onDispose: onDispose);
    _instances.putIfAbsent(T, () => <String, DiElement>{})[tagKey] = item;
    if (registerRuntimeType && runtimeType != T) {
      _instances.putIfAbsent(runtimeType, () => <String, DiElement>{})[tagKey] = item;
    }
    return instance;
  }

  void reset() {
    _isClosed = false;
    _instances.clear();
    _subScopes.clear();
  }

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
  int get hashCode => name.hashCode ^ _parent.hashCode ^ _instances.hashCode ^ _subScopes.hashCode ^ _isClosed.hashCode;

  // ignore: avoid_print
  void verboseTree({bool verboseInstaces = true, String? offset}) {
    var tabs = offset ?? '';
    var items = _instances.values.expand((element) => element.values);
    print("$tabs$name");
    if (verboseInstaces) {
      tabs += '\t';
      for (var i in items) {
        var isReplaced = _parent?.isRegisteredType(i.instance.runtimeType, tag: i.tag) ?? false;
        print(
            "$tabs<${i.instance.runtimeType}> ${i.instance}; ${i.tag == null ? '' : '(${i.tag})'}${isReplaced ? ' overrides (${_parent?.name});' : ''}");
      }
    }

    for (var s in _subScopes) {
      s.verboseTree(verboseInstaces: verboseInstaces, offset: tabs);
    }
  }
}

class DiElement<T> {
  T? _instance;
  final ValueGetter<T>? instancer;
  final String? tag;
  final DisposeCallback<T>? onDispose;

  T get instance {
    _instance ??= instancer?.call();
    return _instance!;
  }

  DiElement.direct({
    required T item,
    this.tag,
    this.onDispose,
  })  : _instance = item,
        instancer = null;

  DiElement.lazy({
    required this.instancer,
    this.tag,
    this.onDispose,
  }) : _instance = null;

  void dispose() {
    if (_instance != null) {
      onDispose?.call(_instance!);
    }
  }

  @override
  String toString() {
    return 'DiElement{instance: $instance, tag: $tag, onDispose: $onDispose}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiElement && runtimeType == other.runtimeType && instance == other.instance && tag == other.tag && onDispose == other.onDispose;

  @override
  int get hashCode => instance.hashCode ^ tag.hashCode ^ onDispose.hashCode;
}
