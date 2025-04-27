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

  DiElement<T>? _elementOf<T>(String? tag) => _instances[T]?[tag ?? ''] as DiElement<T>?;

  DiElement? _elementOfType(Type type, String? tag) => _instances[type]?[tag ?? ''];

  bool contains<T>({String? tag}) => _elementOf<T>(tag) != null;

  bool containsType(Type type, {String? tag}) => _elementOfType(type, tag) != null;

  bool isRegistered<T>({String? tag}) {
    if (contains<T>(tag: tag)) {
      return true;
    }

    return _parent?.contains<T>(tag: tag) ?? false;
  }

  bool isRegisteredType(Type type, {String? tag}) {
    if (containsType(type, tag: tag)) {
      return true;
    }

    return _parent?.containsType(type, tag: tag) ?? false;
  }

  T call<T>({String? tag}) => find<T>(tag: tag);

  T find<T>({String? tag}) {
    _assertOpen();

    final DiElement<T>? element = _elementOf<T>(tag);
    if (element != null) {
      return element.instance;
    }

    final parent = _parent?.find<T>(tag: tag);
    if (parent == null) {
      throw InstanceNotFoundException(T, this);
    }

    return parent;
  }

  T replace<T>(T instance, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    if (contains<T>()) {
      evict<T>(tag: tag);
    }

    return put<T>(instance, tag: tag, onDispose: onDispose);
  }

  void replaceLazy<T>(ValueGetter<T> instancer, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    if (contains<T>()) {
      evict<T>(tag: tag);
    }

    return putLazy<T>(instancer, tag: tag, onDispose: onDispose);
  }

  void putLazy<T>(ValueGetter<T> instancer, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    var item = _elementOf<T>(tag);
    if (item != null) {
      throw DuplicateInstanceException(T, this);
    }

    var map = _instances.putIfAbsent(T, () => <String, DiElement<T>>{});
    map[tag ?? ''] = DiElement<T>.lazy(instancer: instancer, tag: tag, onDispose: onDispose);
  }

  T put<T>(T instance, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    var item = _elementOf<T>(tag);
    if (item != null) {
      throw DuplicateInstanceException(T, this);
    }

    var map = _instances.putIfAbsent(T, () => <String, DiElement<T>>{});
    map[tag ?? ''] = DiElement<T>.direct(item: instance, tag: tag, onDispose: onDispose);
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

      for (var s in _subScopes) {
        s.close();
      }

      var items = _instances.values.expand((element) => element.values);
      for (var item in items) {
        item.dispose();
      }

      _instances.clear();
    }
  }

  T evict<T>({String? tag}) {
    if (!contains<T>(tag: tag)) {
      throw InstanceNotFoundException(T, this);
    }

    final item = _instances[T]?.remove(tag ?? '') as DiElement<T>?;
    if (item == null) {
      throw InstanceNotFoundException(T, this);
    }

    item.onDispose?.call(item.instance);
    return item.instance;
  }

  void _assertOpen() {
    assert(!_isClosed, "scope '$name' already closed");
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
