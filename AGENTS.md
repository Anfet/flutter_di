# AGENTS

## Purpose

Guidance for AI/code agents working in this repository.

## Project Context

- Package: `simple_service_locator`
- Language: Dart / Flutter package
- Main API surface:
  - `lib/src/di_scope.dart`
  - `lib/src/exceptions.dart`
  - `lib/src/ext/scoped_widget_state.dart`

## Working Rules

- Keep API behavior deterministic and test-covered.
- Prefer minimal, focused changes over broad refactors.
- Preserve backward compatibility unless explicitly requested.
- If behavior changes, update both `README.md` and `CHANGELOG.md`.

## Test Expectations

- Run `flutter test` after code changes.
- Add regression tests for every bug fix.
- Prefer clear test names describing behavior, not implementation details.

## Release Hygiene

- If repository has uncommitted changes and release metadata is touched:
  - bump `pubspec.yaml` version
  - add a top entry in `CHANGELOG.md`
  - include a `Breaking Changes` section when relevant

## Documentation Expectations

- Keep README pub.dev-friendly:
  - short value proposition
  - installation line
  - minimal quick-start
  - one advanced usage example
  - lifecycle/disposal notes
