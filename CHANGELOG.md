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
