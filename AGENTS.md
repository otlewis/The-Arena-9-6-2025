# Repository Guidelines

## Project Structure & Module Organization
Flutter sources live under `lib/`, organized by feature (`lib/features/arena`, `lib/features/discussion`) with shared utilities in `lib/core` and `lib/services`. Platform scaffolding sits in `android/`, `ios/`, and `web/`. Keep generated configuration in `lib/config` and localization packs in `lib/l10n`. UI assets are stored in `assets/` (icons, images, audio) and must be declared in `pubspec.yaml`. Deployment helpers live in `scripts/` and root-level `*.sh` files. Node-based helpers (e.g., Agora token service) live in `src/` and `server/`, while integration stubs sit in `unified-*/` and `websocket-*` directories.

## Build, Test, and Development Commands
- `flutter pub get` — installs Dart and Flutter dependencies.
- `flutter analyze` — runs static analysis using rules from `analysis_options.yaml`.
- `dart format lib test` — applies the repository-standard formatting (2-space indent).
- `dart run build_runner build --delete-conflicting-outputs` — regenerates Riverpod, Freezed, and Hive code.
- `flutter run` — launches the client on a connected device or emulator.
- `flutter test` / `flutter test integration_test/` — execute unit, widget, and integration suites.
- `node src/main.js` — starts the local Agora/Appwrite token microservice.

## Coding Style & Naming Conventions
Follow Flutter defaults: two-space indent, `const` where possible, and descriptive `final` fields. Name Dart files with `snake_case.dart`, classes and enums with `PascalCase`, providers with `<noun>Provider`, and Riverpod notifiers with `<Feature>Controller`. Run `dart format` and `flutter analyze` before pushing; the CI mirrors these checks. Keep generated code (`*.g.dart`, `*.freezed.dart`) out of manual edits and ensure they remain in source control when regeneration changes them.

## Testing Guidelines
Place unit tests beside related code under `test/feature_name/`, named `*_test.dart`. Prefer Riverpod `ProviderContainer` for state tests and use `mockito` for network/service seams. Integration scenarios belong in `integration_test/` with clear setup/teardown. Maintain or improve coverage on touched modules; when adding async services, include regression tests to assert Appwrite and LiveKit flows. Run `flutter test --coverage` before large PRs.

## Commit & Pull Request Guidelines
Commit messages should use the imperative mood (`Fix audio queue timing`, `Add LiveKit reconnection guard`) and focus on a single change set. Reference affected modules in the body when cross-cutting. PRs must include: summary, testing evidence (`flutter test` output snippet or coverage note), linked issues, and screenshots or screen recordings for UI updates. Call out migrations or scripts that require operator action. Tag relevant reviewers for Flutter, token service, or backend changes to keep the feedback loop tight.
