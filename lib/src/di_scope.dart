import 'package:flutter/foundation.dart';
import 'package:siberian_di/src/exceptions.dart';

typedef DisposeCallback<T> = void Function(T);

const _kRootScope = 'RootScope';

// ignore: non_constant_identifier_names
final RootScope = DiScope._app();

class DiScope {
  final String name;
  final DiScope? _parent;
  final Map<Type, List<DiElement>> _instances = {};
  final List<DiScope> _subScopes = [];
  bool _isClosed = false;

  DiScope._app()
      : name = _kRootScope,
        _parent = null;

  DiScope.open(
    this.name, {
    DiScope? parent,
  }) : _parent = parent ?? RootScope {
    _parent?._subScopes.add(this);
  }

  Iterable<DiElement<T>> _elementsOf<T>(String? tag) {
    final elements = (_instances[T] ?? <DiElement<T>>[]).cast<DiElement<T>>();
    return elements.where((it) => it.tag == tag);
  }

  Iterable<DiElement> _elementsOfType(Type type, String? tag) {
    final elements = (_instances[type] ?? <DiElement>[]).cast<DiElement>();
    return elements.where((it) => it.tag == tag);
  }

  bool contains<T>({String? tag}) {
    var elements = _elementsOf<T>(tag);
    return elements.isNotEmpty;
  }

  bool containsType(Type type, {String? tag}) {
    var elements = _elementsOfType(type, tag);
    return elements.isNotEmpty;
  }

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

  T find<T>({String? tag}) {
    _assertOpen();
    final elements = _elementsOf<T>(tag);
    assert(elements.length <= 1);
    if (elements.isNotEmpty) {
      return elements.first.instance as T;
    }

    T? element = _parent?.find<T>(tag: tag);
    if (element != null) {
      return element;
    }

    throw InstanceNotFoundException(T, this);
  }

  T replace<T>(T instance, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    Iterable<DiElement<T>> elements = _elementsOf<T>(tag);

    if (elements.isNotEmpty) {
      evict<T>(tag: tag);
    }

    return put<T>(instance, tag: tag, onDispose: onDispose);
  }

  T put<T>(T instance, {String? tag, DisposeCallback<T>? onDispose}) {
    _assertOpen();
    Iterable<DiElement<T>> elements = _elementsOf<T>(tag);

    if (elements.isNotEmpty) {
      throw DuplicateInstanceException(T, this);
    }

    var items = _instances.putIfAbsent(T, () => []);
    items.removeWhere((it) => it.instance.runtimeType == instance.runtimeType && it.tag == tag);
    items.add(DiElement<T>(instance: instance, tag: tag, onDispose: onDispose));
    return instance;
  }

  void reset() {
    _isClosed = false;
    _instances.clear();
    _subScopes.clear();
  }

  void close() {
    if (!_isClosed) {
      _parent?._subScopes.remove(this);
      for (var list in _instances.values) {
        for (var item in list) {
          item.dispose();
        }
      }

      _instances.clear();

      for (var s in _subScopes) {
        s.close();
      }
      _isClosed = true;
    }
  }

  T evict<T>({String? tag}) {
    if (!contains<T>(tag: tag)) {
      throw InstanceNotFoundException(T, this);
    }

    var items = (_instances[T] ?? <DiElement<T>>[]).cast<DiElement<T>>();
    assert(items.length == 1);
    var item = items.removeAt(0);
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
    var items = _instances.values.expand((element) => element);
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

@immutable
class DiElement<T> {
  final T instance;
  final String? tag;
  final DisposeCallback<T>? onDispose;

  const DiElement({
    required this.instance,
    this.tag,
    this.onDispose,
  });

  void dispose() => onDispose?.call(instance);

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
