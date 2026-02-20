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
- Register lazy instances: `putLazy<T>()`, `replaceLazy<T>()`
- Resolve dependencies: `find<T>()` or `scope<T>()`
- Support abstraction + implementation lookup for same object
- Support tagged registrations (`tag`)
- Remove instances (`evict<T>()`)
- Scope tree lookup by name (`locateScope`)
- Widget helper mixin (`ScopedWidgetState`)

## Getting Started

```yaml
dependencies:
  simple_service_locator: ^0.1.0
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

## Lookup Behavior

- `find<T>()` (default `exactTypeMatch: false`) can resolve descendants by runtime type.
- `find<T>(exactTypeMatch: true)` restricts lookup to exact registered type keys.
- `put<T>(instance)` registers under `T`, and by default also under `instance.runtimeType`.
- Set `registerRuntimeType: false` to disable runtime-type alias registration.

## Flutter Widget Scope Helper

```dart
class ProfilePageState extends State<ProfilePage> with ScopedWidgetState<ProfilePage> {
  @override
  void injectDependencies() {
    scope.put<ProfileViewModel>(ProfileViewModel(RootScope.find()));
  }
}
```

## Cases That Fit Pub.dev Consumers Well

- multi-environment service wiring (prod/stage/dev with tags)
- per-feature service overrides in large apps
- test-friendly replacement of interfaces with fakes
- explicit lifecycle control for expensive resources
- no-codegen DI for small and medium Flutter projects

## Notes

- If an instance is missing, `InstanceNotFoundException` includes requested type, scope, and tag.
- Closing a scope disposes registered instances once, even when they were registered under multiple type aliases.
