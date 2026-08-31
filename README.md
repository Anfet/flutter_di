# simple_service_locator

Lightweight hierarchical dependency injection for Flutter.

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
  simple_service_locator: ^0.3.0
```

## Quick Usage

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
}
```

## Scopes And Overrides

```dart
final appScope = DiScope.open('app');
appScope.put<ApiClient>(ApiClientProd());

final featureScope = DiScope.open('feature', knownParentScope: appScope);
featureScope.put<ApiClient>(ApiClientMock()); // local override

final fromFeature = featureScope.find<ApiClient>(); // ApiClientMock
final fromApp = appScope.find<ApiClient>(); // ApiClientProd

appScope.close(); // closes children and disposes registered instances
```

## Observing Scope Changes

`DiScope` extends Flutter's `ChangeNotifier`. A listener is called after a
registration is added, replaced, or evicted, and when child scopes are opened
or closed.

A listener may mutate the scope it observes — open a child scope, register a
dependency, or close the scope itself. Nested notifications triggered from
inside a listener are suppressed, so the listener is not re-entered before it
returns; the outer notification already reports the final state.

```dart
final scope = DiScope.open('cart');
scope.addListener(() {
  // Refresh state derived from this scope.
});

scope.put<CartService>(CartService());
```

## Tags

```dart
RootScope.put<String>('https://prod.example.com', tag: 'prod');
RootScope.put<String>('https://staging.example.com', tag: 'staging');

final prod = RootScope.find<String>(tag: 'prod');
final staging = RootScope.find<String>(tag: 'staging');
```

## Lazy Registration

```dart
RootScope.putLazy<ExpensiveService>(() => ExpensiveService());
final service = RootScope.find<ExpensiveService>(); // created on first access
```

For an abstraction and implementation pair, use explicit lazy keys:

```dart
RootScope.putLazyAs<UserRepository, UserRepositoryFirebase>(
  () => UserRepositoryFirebase(),
);
final byAbstraction = RootScope.find<UserRepository>();
final byImplementation = RootScope.find<UserRepositoryFirebase>();
```

Registration checks, replacements, diagnostics, and closing an unused lazy
registration do not invoke its factory. A factory that throws leaves its
registration unmaterialized, so the next lookup retries it.

## Lookup Behavior

- `find<T>()` resolves explicit registration keys only; it does not infer supertypes or interfaces from an instance's runtime type.
- `find<T>(searchDescendants: true, onMany: ...)` also searches child scopes.
- `findInChildren<T>(onMany: ...)` searches only child scopes; without `onMany` it throws `MultipleInstancesFoundException` on ambiguous matches.
- `put<A>(B())` registers the same instance under both `A` and `B` by default, so either key can resolve it.
- `put<B>(B())` registers only `B`; resolving an interface or superclass requires registering that type explicitly.
- `putLazyAs<A, B>(() => B())` lazily registers both explicit keys. `putLazy<A>()` registers only `A`.
- Set `registerRuntimeType: false` to disable runtime-type alias registration.
- Keys are non-nullable (`T extends Object`). Register an explicit wrapper or a
  sentinel value when you need to model "configured, but absent".

## Advanced Scope Queries

```dart
final root = DiScope.open('root');
final auth = DiScope.open('auth', knownParentScope: root);
final profile = DiScope.open('profile', knownParentScope: root);

auth.put<ApiClient>(ApiClientProd(), tag: 'prod');
profile.put<ApiClient>(ApiClientMock(), tag: 'mock');

final prodOnlyScopes = root.locateScopes<ApiClient>(tag: 'prod');
final taggedScopes = root.locateScopesByTag('mock');
```

## Flutter Scope Lifecycle Helper

```dart
class ProfilePageState extends State<ProfilePage> with ScopeProviderState<ProfilePage> {
  @override
  String get scopeName => 'profile';

  @override
  DiScope get parentScope => RootScope;

  @override
  void injectDependencies() {
    super.injectDependencies();
    scope.put<ProfileViewModel>(ProfileViewModel(RootScope.find()));
  }
}
```

`ScopeProviderState` is context-less: pass a [DiScope] explicitly through a
constructor or use a known globally unique scope name when another object must
access it. There is no widget consumer lookup helper.

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

## Cases That Fit Pub.dev Consumers Well

- multi-environment service wiring (prod/stage/dev with tags)
- per-feature service overrides in large apps
- test-friendly replacement of interfaces with fakes
- explicit lifecycle control for expensive resources
- no-codegen DI for small and medium Flutter projects

## Notes

- If an instance is missing, `InstanceNotFoundException` includes requested type, scope, and tag.
- Closing a scope disposes registered instances once, even when they were registered under multiple type aliases.
- If a disposal callback throws, the scope still closes and disposes remaining registrations before rethrowing the first error.
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
