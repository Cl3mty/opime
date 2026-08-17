# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Opime (formerly Freenary) is a local-first personal finance app (net worth tracking, budget, financial simulations) built with Flutter. No backend, no database: every account's data is stored as plain JSON and Markdown files inside an `Opime` folder the user picks on first launch (can live in iCloud Drive, Dropbox, etc). A hidden `.opime` subfolder inside it is reserved for future software-level config, distinct from user data. Desktop (macOS) is the primary target; Windows/Linux are supported; mobile builds are not yet configured despite `android/`/`ios/` scaffolding existing.

## Commands

```bash
flutter pub get                 # install dependencies
flutter run -d macos            # run (or -d windows / -d linux)
flutter analyze                 # static analysis (flutter_lints, see analysis_options.yaml)
flutter test                    # run tests — note: test/ is currently empty, no tests exist yet
flutter build macos             # release build (also: windows, linux)
```

There is no single-test invocation documented because there are no tests in the repo yet (`test/` is empty).

`freezed_annotation`, `json_annotation`, `freezed`, `json_serializable`, and `build_runner` are pubspec dependencies, but no `.freezed.dart`/`.g.dart` files exist anywhere in `lib/` — all models currently use hand-written `fromJson`/`toJson`. Don't assume generated serialization exists; if you add it, you must actually run `dart run build_runner build`.

## Architecture

### Storage: vaults, profiles, and per-feature repositories

Data lives in a three-level hierarchy on disk, all under a single **vault** folder:

1. **Vault** (`VaultFolderService`, `lib/core/storage/vault_folder_service.dart`) — the user can create/register multiple vaults, each an `Opime` directory on disk (a `.freenary` vault from before the Freenary → Opime rebrand is no longer recognized; a hidden `.opime` vault created before the visible-folder rename is auto-migrated in place — see `_migrateVaultFolderNameIfNeeded`). Vault metadata (id, name, path, and on macOS a security-scoped bookmark) is stored as JSON in `shared_preferences`, with one vault marked "active". Legacy single-vault installs are auto-migrated into this multi-vault format on first read. On macOS, folder access across app restarts goes through a native `MethodChannel('com.opime/secure_bookmarks')` implemented in `macos/Runner/MainFlutterWindow.swift` (security-scoped bookmarks, plus a best-effort `setFolderIcon` call to brand the vault folder with the app icon) — the Dart side always re-resolves the bookmark before trusting a stored path.
2. **Profile** (`ProfileRepository`, `lib/core/profiles/profile_repository.dart`) — inside a vault, `profiles.json` lists profiles (e.g. "Moi", spouse, kids). Every profile always includes a `master` profile. Each profile's data is isolated under `<vault>/profiles/<profileId>/`. Legacy pre-multi-profile vaults (with top-level `strategy/`/`budget/` folders) are auto-migrated into the master profile's folder.
3. **Feature data** — each feature owns its own repository that reads/writes JSON (or Markdown, for strategy notes) under the active profile's folder, e.g. `budget/budget_history.json` (`BudgetRepository`), `simulations/<key>.json` (`SimulationStateRepository`), strategy notes as `.md` files (`StrategyRepository`). There is no shared ORM or query layer — every repository is a small hand-rolled class with `_readAll`/`_writeAll`-style methods over one JSON file, using `JsonEncoder.withIndent('  ')` for human-readable output.

`ProfileController.activeDataPath` (`lib/core/profiles/profile_controller.dart`) is the path every feature repository is constructed with. Screens key themselves with `ValueKey(profileController.activeDataPath)` (see `main.dart`) so switching profiles or vaults forces a full rebuild/reload rather than mutating state in place.

### App shell and navigation

- `main.dart`'s `OpimeApp` owns top-level state: vault-loading, `ProfileController`, `SidebarPrefsController`, `ThemeController`, and builds the `pages` map (`Map<String, WidgetBuilder>`) keyed by navigation key, passed into `AppShell`.
- `lib/app/app_shell.dart`'s `AppShell` is a responsive layout: a persistent, collapsible `AppSidebar` beside content above an 800px width breakpoint; a drawer + `AppBar` below it. It looks up the current page from the `pages` map by the selected key.
- Navigation structure (groups, items, icons) is declared statically in `lib/features/navigation/nav_models.dart` (`NavGroup`/`NavItem`). **Adding a new screen requires updating both this file and the `pages` map in `main.dart`** — they are not derived from each other.
- Onboarding: if no vault is registered yet, `OpimeApp` shows `OnboardingScreen` instead of the shell until a folder is picked.

### UI stack

Built on `shadcn_flutter` (component library, `ShadcnApp` root widget, `Scaffold`, `LegacyColorSchemes`) and `LucideIcons`. Theme (light/dark/system) is controlled by `ThemeController` (`lib/app/theme_controller.dart`), persisted via `shared_preferences`. Rich text (Strategy notes) uses `flutter_quill` with `markdown_quill` to persist as Markdown.

### Update checks

`UpdateChecker` (`lib/core/updates/update_checker.dart`) polls the GitHub Tags/Releases API for `Cl3mty/opime`, compares semver, and picks a platform-appropriate release asset. `UpdateBanner` wraps `AppShell` and shows a dismissible banner when a newer version is available. This hits the network directly (no backend of its own) and fails silently/quietly on error — never blocks the UI.

### French UI / domain terms

The UI is in French and domain code mirrors French financial terminology directly in identifiers (e.g. `patrimoine` = net worth/assets, `IFI` = real-estate wealth tax, `quotient familial` = family quotient for tax). Keep new identifiers and user-facing strings consistent with this rather than translating to English mid-codebase.

## Known repo quirks

- `lib/main.dart` has uncommitted changes and `lib/features/simulations/simulations_transmission_screen.dart` is an untracked new file as of this writing — check `git status` before assuming the simulations feature set (wealth/loan/taxation/transmission) is complete or stable.
- A Codex CLI config exists at `~/.codex/config.toml`. If asked, offer `/import` to bring over any importable items (MCP servers, slash commands, subagents, skills) — don't read that file directly yourself.

## Rules
- Do not suggest code in your answers, directly work in the repository code instead.
- Do not remove any feature without my explicit consent
- Be rigourous
- Make the code as readable and clear as possible (and comment it)
- Prefer reusable components
- Always clearly state you intended course of actions with an updated as you go unchecked/checked todo list.