## 0.2.0

### Added

- `putLazyAs<A, B>()` and `replaceLazyAs<A, B>()` for lazy registrations with
  explicit abstraction and implementation keys.

### Changed

- Dependency lookup now resolves only explicit registration keys.
- `put<A>(B())` still registers both `A` and concrete type `B` by default.
- `DiScope.close()` now completes descendant and registration cleanup before
  rethrowing the first disposal or listener error.
- Lazy factories are invoked only by resolution, not by registration checks,
  replacements, or diagnostics.
- Scope names must be non-empty.
- Closed scopes can no longer be reopened with `reset()`.
- Enabled strict cast, inference, and raw-type checks in the Dart analyzer.

### Fixed

- `evict` now supports removal through a concrete runtime-type alias.
- Missing-instance errors now report the scope where lookup started.
- Widget scope disposal always invokes `State.dispose()`.
- Scope-tree traversal uses FIFO queues instead of repeatedly shifting lists.
- Direct `RootScope.close()` now rejects the same way as `closeScope('RootScope')`.

### Breaking Changes

- Removed implicit assignable-type lookup. After `put<B>(B())`, `find<A>()`
  now throws unless `A` was explicitly registered.
- Removed the `exactTypeMatch` parameter from `call`, `find`, `findInChildren`,
  and `locateScopes`; all lookups now use explicit keys.
- `reset()` now closes child scopes and disposes local registrations before
  keeping the current scope reusable.
- `DiScope` and `DiElement` now use identity equality. The previous structural
  equality and mutable hash codes were removed.
- Removed `ScopeConsumerState` from the public API. Pass a [DiScope] explicitly
  or use an explicit lookup by globally unique scope name.
- `ScopeProviderState.scopeName` is now required. `parentScope` can be
  overridden to attach to an explicit parent scope.

## 0.1.5

### Added

- `DiScope` now extends `ChangeNotifier` and notifies listeners after scope and registration changes.

## 0.1.4

### Added

- Widget tests covering scope provision, scope consumption, and missing scope errors.

### Changed

- Updated public library docs to reference `ScopeProviderState` and `ScopeConsumerState`.

### Breaking Changes

- `ScopedWidgetState` was split into `ScopeProviderState` and `ScopeConsumerState`.
- Update widget mixin usages and imports to the new names.

## 0.1.3

### Added

- `ScopedWidgetState.scopeName` overridable getter for custom widget scope naming.
- Widget tests covering:
  - custom scope name usage
  - automatic scope close on widget dispose

### Changed

- `ScopedWidgetState` now initializes scope inside `injectDependencies()`; method is marked `@mustCallSuper`.

## 0.1.2

### Added

- Child-scope-only dependency lookup:
  - `DiScope.findInChildren<T>({tag, exactTypeMatch, onMany})`
  - throws `MultipleInstancesFoundException` when more than one child scope matches and no `onMany` resolver is provided
- Optional child-tree lookup on `find`:
  - `DiScope.find<T>({..., searchDescendants: true, onMany})`
  - keeps default behavior unchanged when omitted (`false`)
- Scope discovery by local registrations:
  - `DiScope.locateScopes<T>({tag, exactTypeMatch, includeSelf})`
  - `DiScope.locateScopesByTag(tag, {includeSelf})`

### Changed

- Removed internal `_rootScope()` traversal and inlined duplicate scope checks against `RootScope`.
- Added regression tests for child lookup:
  - successful resolution in nested descendants
  - not-found behavior
  - ambiguity details in `MultipleInstancesFoundException`
  - `find(..., searchDescendants: true)` and default non-descendant behavior

## 0.1.1

### Added

- Added publish-ready package example:
  - `example/simple_service_locator_example.dart`
- Expanded dartdoc coverage for public API:
  - exception constructors
  - `DiElement` public fields

### Changed

- Improved `DiScope.verboseTree` parameter naming:
  - added `verboseInstances`
  - kept `verboseInstaces` for backward compatibility

## 0.1.0

### Added

- Regression test for abstraction-chain resolution:
  - register as base contract
  - resolve as intermediate contract
  - resolve as concrete implementation
- Pub.dev-oriented README with practical setup and usage examples.
- `AGENTS.md` with repository contribution/release notes for coding agents.

### Changed

- Package renamed to `simple_service_locator`.
- Primary public entrypoint is now `lib/simple_service_locator.dart`.
- Updated package imports in library sources and tests to:
  - `package:simple_service_locator/simple_service_locator.dart`
- Fixed descendant lookup in `DiScope.find<T>()` for aliased runtime registrations.
- Improved `pubspec.yaml` metadata for pub.dev (`description`, links, topics).
- Lint cleanup across source/tests.

### Breaking Changes

- Import path changed:
  - `package:flutter_di/flutter_di.dart`
  - to `package:simple_service_locator/simple_service_locator.dart`
- Package dependency name changed:
  - `flutter_di`
  - to `simple_service_locator`

## 0.0.1

- Initial release.
