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
  simple_service_locator: ^0.2.0
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
registration do not invoke its factory.

## Lookup Behavior

- `find<T>()` resolves explicit registration keys only; it does not infer supertypes or interfaces from an instance's runtime type.
- `find<T>(searchDescendants: true, onMany: ...)` also searches child scopes.
- `findInChildren<T>(onMany: ...)` searches only child scopes; without `onMany` it throws `MultipleInstancesFoundException` on ambiguous matches.
- `put<A>(B())` registers the same instance under both `A` and `B` by default, so either key can resolve it.
- `put<B>(B())` registers only `B`; resolving an interface or superclass requires registering that type explicitly.
- `putLazyAs<A, B>(() => B())` lazily registers both explicit keys. `putLazy<A>()` registers only `A`.
- Set `registerRuntimeType: false` to disable runtime-type alias registration.

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
  String get scopeName => 'profile:${widget.profileId}';

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
- `RootScope` is process-lifetime and cannot be closed. `reset()` closes child scopes and disposes registrations while keeping the current scope reusable.
