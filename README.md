# simple_service_locator

Lightweight hierarchical dependency injection for Flutter.

Requires Flutter 3.38.0 or newer and Dart 3.10.0 or newer.

`simple_service_locator` is built around explicit runtime scopes (`DiScope`) with:
- parent/child scope resolution
- tagged registrations
- lazy factories
- deterministic disposal
- type-safe lookup by abstraction and implementation

## Why This Package

Useful when you need:
- app-wide services in a root scope
- feature/page-local overrides in child scopes
- predictable disposal on scope close
- direct control without code generation

## Features

- Register direct instances: `put<T>()`, `replace<T>()`
- Register lazy instances: `putLazy<T>()`, `replaceLazy<T>()`, `putLazyAs<A, B>()`, `replaceLazyAs<A, B>()`
- Resolve dependencies: `find<T>()` or `scope<T>()`
- Resolve in descendants only: `findInChildren<T>()`
- Support abstraction + implementation lookup for same object
- Support tagged registrations (`tag`)
- Remove instances (`evict<T>()`)
- Scope tree lookup by name (`locateScope`)
- Scope lookup by registration/type tag (`locateScopes`, `locateScopesByTag`)
- Listen for scope changes with `addListener()`
- Widget scope lifecycle mixin (`ScopeProviderState`)

## Getting Started

```yaml
dependencies:
  simple_service_locator: ^0.4.0
```

## Quick Start

```dart
import 'package:simple_service_locator/simple_service_locator.dart';

abstract interface class UserRepository {}

class UserRepositoryFirebase implements UserRepository {}

void setup() {
  RootScope.replace<UserRepository>(UserRepositoryFirebase());
}

void useIt() {
  final userRepository = RootScope.find<UserRepository>();
  final sameInstanceByImpl = RootScope.find<UserRepositoryFirebase>();
  assert(identical(userRepository, sameInstanceByImpl));
}

void main() {
  setup();
  useIt();
  RootScope.reset();
}
```

## Advanced Usage

`DiScope` extends Flutter's `ChangeNotifier`. A listener is called after a
registration is added, replaced, or evicted, and when child scopes are opened
or closed.

A listener may mutate the scope it observes — open a child scope, register a
dependency, or close the scope itself. Nested notifications do not re-enter
listeners; one follow-up notification is queued for the next asynchronous
event-loop turn so listeners can observe the nested mutation. A mutation made
during that follow-up is applied but does not queue a third notification; this
bounds one synchronous dispatch to two listener invocations.

```dart
import 'package:simple_service_locator/simple_service_locator.dart';

abstract interface class ApiClient {}

class ProductionApiClient implements ApiClient {}

class MockApiClient implements ApiClient {}

void main() {
  final appScope = DiScope.open('app');
  appScope.put<ApiClient>(ProductionApiClient(), tag: 'prod');

  final featureScope = DiScope.open('feature', knownParentScope: appScope);
  featureScope.putLazy<ApiClient>(() => MockApiClient(), tag: 'test');
  final client = featureScope.find<ApiClient>(tag: 'test');
  final productionScopes = appScope.locateScopes<ApiClient>(tag: 'prod');

  assert(client is MockApiClient);
  assert(productionScopes.single == appScope);

  appScope.addListener(() {});
  featureScope.close();
  appScope.close(); // closes remaining children and disposes registrations
}
```

Registration checks, replacements, diagnostics, and closing an unused lazy
registration do not invoke its factory. A factory that throws leaves its
registration unmaterialized, so the next lookup retries it.

Use `putLazyAs<A, B>()` to make both abstraction and implementation keys
available lazily. `putLazy<A>()` registers only `A`.

## Lookup Behavior

- `find<T>()` resolves explicit registration keys only; it does not infer supertypes or interfaces from an instance's runtime type.
- `find<T>(searchDescendants: true)` searches descendants after current and ancestor lookup; `findInChildren<T>()` searches descendants only. Both throw `MultipleInstancesFoundException` on multiple matches before creating lazy values. With `onMany`, multiple matches are materialized in breadth-first tree order before the callback; a single match is returned directly.
- `put<A>(B())` registers the same instance under both `A` and `B` by default, so either key can resolve it.
- `put<B>(B())` registers only `B`; resolving an interface or superclass requires registering that type explicitly.
- `putLazyAs<A, B>(() => B())` lazily registers both explicit keys. `putLazy<A>()` registers only `A`.
- Set `registerRuntimeType: false` to disable runtime-type alias registration.
- Keys are non-nullable (`T extends Object`). Register an explicit wrapper or a
  sentinel value when you need to model "configured, but absent".

## Flutter Scope Lifecycle Helper

`ScopeProviderState` is context-less: pass a [DiScope] explicitly through a
constructor or use a known globally unique scope name when another object must
access it. There is no widget consumer lookup helper.

Mix `ScopeProviderState<YourWidget>` into the widget's `State`, provide a
globally unique `scopeName`, and register state-local dependencies in
`injectDependencies()` after calling `super.injectDependencies()`.

### Scope Lifetime

The scope belongs to the `State`, not to the widget configuration:

- `scopeName` is read once, when the scope is opened. Deriving it from a widget
  field (`'profile:${widget.profileId}'`) does **not** reopen the scope when
  that field changes — the state keeps the scope it opened. Put a `ValueKey` on
  the widget when a new configuration must get a fresh scope and fresh
  dependencies.
- The scope is released in `deactivate()` and reopened in `activate()`, so the
  name is free as soon as the state leaves the tree. This keeps an ordinary
  widget replacement (Flutter runs the new `initState()` before the old
  `dispose()`) from throwing `DuplicateScopeException`.
- Because a deactivated state's scope is closed and rebuilt, anything
  registered in `injectDependencies()` is recreated when the state is
  reinserted through a `GlobalKey` move. Dependencies that must survive such a
  move belong in a parent scope.
- If `onDispose` throws while the state is deactivated, Flutter's lifecycle
  still completes and the error is reported after the frame with its original
  stack trace.

## Notes

- If an instance is missing, `InstanceNotFoundException` includes requested type, scope, and tag.
- Closing a scope disposes registered instances once, even when they were registered under multiple type aliases.
- If a disposal callback throws, the scope still closes and disposes remaining registrations before rethrowing the first error.
- If a `replace*()` disposal callback throws and the replacement keys remain
  free, the replacement is installed before the original error and stack trace
  are rethrown. If the callback registers a key needed by the replacement and
  leaves the scope open, that registration is retained and the call reports
  `DuplicateInstanceException`; when the callback also throws, its original
  error takes precedence.
- If the disposal callback closes the scope, no replacement is installed and
  the call throws `StateError`, unless the callback also throws, in which case
  its error takes precedence.
- Scope names must be non-empty.
- `DiScope.open(..., lookupParentScope: name)` throws `ScopeNotFoundException`
  when `name` does not resolve. Omit the argument to attach to `RootScope`.
- Presence checks (`contains`, `isRegistered`) throw `StateError` on a closed
  scope rather than answering `false`.
- Registration and lookup keys must be non-nullable. `put<T?>(...)`,
  `find<T?>()` and friends do not compile: every generic entry point is bound
  as `T extends Object`, so a missing dependency is always a
  `InstanceNotFoundException` rather than a silent `null`.
- `RootScope` is process-lifetime and cannot be closed. `reset()` closes child scopes and disposes registrations while keeping the current scope reusable.
