## 1. Launch-Argument Plumbing & Composition Root

- [ ] 1.1 Add `ScreenshotMode` enum/helper that reads `-InfStoriesScreenshotMode` and `-InfStoriesScreenshotLocale` from `UserDefaults.standard`, returning `(enabled: Bool, locale: String?)`. Gate all reads behind `#if DEBUG`; provide a stubbed `disabled` return path under non-DEBUG.
- [ ] 1.2 Add a `RepositoryFactory` (or extend `AppConfiguration`) with `makeHeroRepository()`, `makeStoryRepository()`, `makeCustomEventRepository()`, `makeReadingJourneyRepository()` that return API-backed implementations by default and fixture-backed implementations when screenshot mode is active (`#if DEBUG` guarded).
- [ ] 1.3 Audit every site that constructs a repository (e.g., `HeroRepository(apiClient:)`) and route construction through `RepositoryFactory` so screenshot mode actually swaps the implementation.
- [ ] 1.4 Add `ReadingJourneyRepositoryProtocol` to `ReadingJourneyRepository.swift` if missing; make the existing concrete class conform; update injection sites.
- [ ] 1.5 Add a CI/local guard (script in `tools/screenshots/` or a build phase) that fails if `DEBUG` ever appears in the Release configuration's `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in `project.pbxproj`.

## 2. Authentication Bypass

- [ ] 2.1 In `AuthStateManager`, add a `#if DEBUG`-gated init path that constructs a synthetic authenticated session when `ScreenshotMode.enabled` is true. No Keychain reads/writes, no token-refresh timer, no auth network calls.
- [ ] 2.2 Verify `InfiniteStoriesApp.body` routes to `MainTabView` (not `AuthenticationView`) under the synthetic session.
- [ ] 2.3 Add a unit test (Debug-only target) asserting that with the screenshot-mode launch args set, `AuthStateManager.isAuthenticated == true` and no Keychain call is made.

## 3. Fixture Format & Loader

- [ ] 3.1 Create `infinite-stories-ios/InfiniteStories/Resources/ScreenshotFixtures/{en,fr}/` with empty placeholders for `auth.json`, `heroes.json`, `custom-events.json`, `stories.json`, `reading-journey.json`, `preferences.json`, and an `assets/` PNG folder.
- [ ] 3.2 Implement `ScreenshotFixtureLoader` that reads the locale-specific fixture set from the app bundle and decodes through the existing `Codable` model types used by API responses. Decode failures MUST be fatal (no silent fallback).
- [ ] 3.3 Ensure fixture resources are included in the Debug-configuration Copy Bundle Resources phase only (not Release/Beta) — verify in `project.pbxproj` build phases.
- [ ] 3.4 Author the English fixture set: 1 hero ("Lucas") with a pre-baked avatar PNG, 1 custom event ("First day at school"), 1 generated story with a localized title, a localized story body excerpt, and stub illustration metadata + bundled illustration PNGs. Include matching `reading-journey.json` stats and `preferences.json`.
- [ ] 3.5 Author the French fixture set: parallel structure with French strings — hero ("Léa"), custom event ("Première journée d'école"), story title/body in French, etc. No English strings except brand names.

## 4. Fixture-Backed Repository Implementations

- [ ] 4.1 Implement `FixtureHeroRepository: HeroRepositoryProtocol`. All CRUD/avatar/visual-profile methods return data from the loaded fixtures or no-op on writes.
- [ ] 4.2 Implement `FixtureStoryRepository: StoryRepositoryProtocol`. Return fixture stories; for generation calls, return the pre-baked fixture story instead of contacting the backend.
- [ ] 4.3 Implement `FixtureCustomEventRepository: CustomEventRepositoryProtocol`. Return fixture custom events.
- [ ] 4.4 Implement `FixtureReadingJourneyRepository: ReadingJourneyRepositoryProtocol`. Return fixture stats and chart series.
- [ ] 4.5 Add a `FixtureAudioService` that conforms to the `AudioService` interface used by `StoryViewModel` and exposes a "paused at known frame" state — no AVAudioEngine, no MP3 fetch. Route `StoryViewModel` to use it under screenshot mode.

## 5. Locale Application

- [ ] 5.1 Extend `LocalizationManager.shared.applyLanguageOverrideAtLaunch()` to honor `-InfStoriesScreenshotLocale` when screenshot mode is active, overriding the normal preference flow.
- [ ] 5.2 Confirm Bundle string lookups, `Localizable.xcstrings`, and date/number formatters all reflect the override (manual smoke test in simulator with `-InfStoriesScreenshotLocale fr`).

## 6. Accessibility-Identifier Coverage

- [ ] 6.1 Audit every screen referenced by the planned manifest (Home, Library, Heroes, Reading Journey + scrolled variants, Settings + scrolled About/Advanced, Hero Creation steps 1–4, Story Generation, Event Picker + scrolled, Audio Player, Custom Events). For each, identify the entry-point tap target and a reliable "wait-ready" view.
- [ ] 6.2 Add `.accessibilityIdentifier(_)` modifiers to those entry-point and wait-ready views using stable names (e.g., `tab.settings`, `settings.deleteAccountButton`, `home.heroCarousel`).
- [ ] 6.3 Add `.accessibilityIdentifier(_)` on scroll-anchor views inside long scroll containers so `scrollTo(id:)` operations work deterministically.

## 7. Capture Script & Manifest

- [ ] 7.1 Create `tools/screenshots/manifest.json` declaring locales (`["en","fr"]`), device (single 6.9" iPhone), and an entry per screen with `id`, `filename`, `navigation` steps, and `wait` identifier.
- [ ] 7.2 Create `tools/screenshots/capture.sh` (or `.ts`/`.swift` runner) that, given a locale: erases the simulator, sets `AppleLanguages`/`AppleLocale` via `xcrun simctl`, applies status-bar override (`xcrun simctl status_bar override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`), installs the Debug build, launches with screenshot-mode args, walks the manifest, and writes PNGs to `screenshots/.staging/<locale>/`.
- [ ] 7.3 Implement atomic swap: after the manifest run for a locale succeeds, `rm -rf screenshots/<locale> && mv screenshots/.staging/<locale> screenshots/<locale>`. On failure, leave staging in place and exit non-zero.
- [ ] 7.4 Add an `--all` flag that runs the locale loop end-to-end; document `./capture.sh en`, `./capture.sh fr`, `./capture.sh --all` in `tools/screenshots/README.md`.
- [ ] 7.5 Add a manifest coverage check (small script) that lists files in `screenshots/en` and `screenshots/fr`, asserts equal sets, and asserts each file maps to a manifest entry. Exit non-zero on mismatch.

## 8. Regenerate Screenshot Sets

- [ ] 8.1 Run `./capture.sh en` end-to-end; visually inspect every output for English-only content, correct UI state, and no debug artifacts.
- [ ] 8.2 Run `./capture.sh fr` end-to-end; visually inspect every output for French-only content (including hero name, custom event title, story title).
- [ ] 8.3 Delete the legacy `screenshots/en/` and `screenshots/fr/` contents and commit the regenerated sets in a single change.

## 9. Documentation & Close-Out

- [ ] 9.1 Update `docs/SCREENSHOT_VERIFICATION.md`: replace the "Known Structural Issue — Locale Cross-Contamination" callout with a "Regenerated via localized pipeline" note pointing to `tools/screenshots/README.md`.
- [ ] 9.2 Update `CLAUDE.md` (project) with a one-line pointer to the screenshot pipeline location.
- [ ] 9.3 In `openspec/changes/app-store-approval-fixes/tasks.md`, mark task 5.2 complete now that screenshots are locale-correct and reproducible; remove the `BLOCKED` note.
- [ ] 9.4 Upload the regenerated screenshot sets to App Store Connect for the next submission; verify display order in the upload UI.
- [ ] 9.5 Archive this change with `openspec archive rework-localized-screenshot-pipeline` once tasks 1–9.4 are complete and the new screenshots are accepted by App Store Connect.
