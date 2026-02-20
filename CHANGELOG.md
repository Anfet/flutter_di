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
