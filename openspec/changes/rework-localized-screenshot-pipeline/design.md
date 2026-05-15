## Context

App Store screenshots for `infinite-stories-ios` are currently captured by hand against a single shared backend account. The captured user content (hero names, custom event titles, story titles) bleeds across locales — French content shows up in `screenshots/en/*.png`, and vice versa — because both runs read the same backend account state. The capture is also non-reproducible: filenames are stable but the rendered content depends on whatever the account happens to contain at capture time.

The app already has the architectural primitives to fix this cleanly:

- `HeroRepository`, `StoryRepository`, `CustomEventRepository` (and `ReadingJourneyRepository`) all sit behind protocols — substitution is feasible without touching call sites.
- `AppConfiguration.swift` already centralises `#if DEBUG` flags and per-environment URLs.
- `LocalizationManager.shared.applyLanguageOverrideAtLaunch()` already supports overriding UI language at launch.
- `AuthStateManager` already gates the root view (`InfiniteStoriesApp.swift:152-167`), so a screenshot-mode short-circuit is local.

The constraint is that the app is API-only in production: Hero/Story aren't persisted, every view loads from the backend. The screenshot pipeline must satisfy those same views' load paths **without** any network round-trip, deterministically, in two locales (EN + FR for v1).

Stakeholders: iOS submission owner (re-uploads to App Store Connect), backend (none — pipeline is iOS-only), QA (validates the manifest).

## Goals / Non-Goals

**Goals:**
- One-command reproducible capture that produces a complete, locale-correct `screenshots/<locale>/` set per supported locale.
- Zero backend dependency during capture — fully offline, hermetic.
- Production code path is unchanged when screenshot mode is off; no runtime risk to shipping app.
- Capture covers every screen in a documented manifest, with identical screen coverage across locales.
- Pipeline structure is trivially extensible to ES/DE/IT later (add a fixture folder + manifest locale entry, no architectural change).

**Non-Goals:**
- Automating upload to App Store Connect.
- Visual regression / pixel-diff CI.
- Replacing or evaluating Fastlane snapshot.
- Migrating any production test or runtime path to fixtures.
- Persisting screenshot-mode artifacts in production builds — debug-only.
- Capturing locales beyond EN + FR in this change.

## Decisions

### 1. Activation: launch arguments, not a build flavor

Screenshot mode is opted into by passing launch arguments to the same `Debug` build:

- `-InfStoriesScreenshotMode YES`
- `-InfStoriesScreenshotLocale en` (or `fr`)

The composition root in `InfiniteStoriesApp.init()` reads `UserDefaults.standard` (which absorbs `-Key Value` launch args), and if `ScreenshotMode` is on, swaps in fixture-backed repositories and forces `AuthStateManager` into an authenticated state.

**Alternative considered:** A separate `Screenshot` build configuration with `#if SCREENSHOT_MODE` guards. Rejected — doubles CI surface, drifts from production, and `xcrun simctl launch -- -arg value` already gives us per-run toggles without rebuilding.

**Safety:** the launch-arg branch is additionally wrapped in `#if DEBUG` so a TestFlight or App Store build cannot enter screenshot mode even if the argument is somehow passed.

### 2. Repository substitution: composition root, no DI framework

Introduce a single `RepositoryFactory` (or extend `AppConfiguration`) that returns the concrete repository instance to use. In production mode it returns the existing API-backed implementations. In screenshot mode it returns new types that conform to the same protocols and are backed by fixtures:

- `FixtureHeroRepository: HeroRepositoryProtocol`
- `FixtureStoryRepository: StoryRepositoryProtocol`
- `FixtureCustomEventRepository: CustomEventRepositoryProtocol`
- `FixtureReadingJourneyRepository: ReadingJourneyRepositoryProtocol` (add protocol if not present)

These types load JSON fixtures from the app bundle at init and serve them synchronously (or with a small artificial delay so loading shimmers render correctly).

**Alternative considered:** A `URLProtocol` interceptor that stubs HTTP. Rejected — heavier, makes debugging captures harder, and still requires fixture data; doesn't save complexity.

### 3. Fixture format: per-locale JSON in app Resources

```
infinite-stories-ios/InfiniteStories/Resources/ScreenshotFixtures/
├── en/
│   ├── auth.json              # synthetic authenticated session
│   ├── heroes.json            # 1–2 heroes with localized names
│   ├── custom-events.json     # localized event titles + descriptions
│   ├── stories.json           # 1+ stories with localized title + body excerpt + cached audio metadata
│   ├── reading-journey.json   # stats counts + chart series
│   ├── preferences.json       # theme, language, story length, voice
│   └── assets/                # pre-baked PNGs for avatars + illustrations
└── fr/
    └── (parallel structure with French strings)
```

Fixtures are bundled as `Resources` (Copy Bundle Resources phase). Loading is done by a small `ScreenshotFixtureLoader` keyed off `-InfStoriesScreenshotLocale`. Avatars and illustration images are bundled as PNGs so the carousel and hero grid don't need real DALL·E calls.

**Alternative considered:** Generating fixtures from a backend snapshot. Rejected — couples the pipeline to backend state we're explicitly trying to escape.

### 4. Auth bypass: `AuthStateManager` honours screenshot mode

In screenshot mode, `AuthStateManager` is constructed in a synthetic `isAuthenticated = true, sessionExpired = false` state with a fixture user identity. `MainTabView` therefore renders without ever talking to auth endpoints. No real Keychain access; no token refresh timer fires.

### 5. Locale + region: simulator-side `xcrun simctl` + app-side `LocalizationManager`

The capture script performs three setup steps per locale before launch:

1. `xcrun simctl boot <UDID>` (or reuse already booted)
2. `xcrun simctl shutdown <UDID>` once + `xcrun simctl spawn <UDID> defaults write -globalDomain AppleLanguages -array <locale> && defaults write -globalDomain AppleLocale -string <locale>_<REGION>` — sets simulator-wide locale so status-bar/system chrome renders correctly.
3. `xcrun simctl launch <UDID> com.infinitestories... -InfStoriesScreenshotMode YES -InfStoriesScreenshotLocale <locale>` — the app then calls `LocalizationManager.shared.applyLanguageOverrideAtLaunch()` (already in `InfiniteStoriesApp.init()`) and the same locale flows into the UI.

Region defaults: `en_US` for English, `fr_FR` for French. Documented in the script, overridable per locale.

### 6. UI navigation: scripted via XcodeBuildMCP-style tap/scroll, keyed on accessibility identifiers

Each captured screen has an entry in a manifest (see Decision 7). For each entry, the capture script:

1. Calls a tap/scroll sequence by accessibility identifier (e.g., `tap(id: "tab.settings")`, `scrollTo(id: "settings.about")`).
2. Waits for an idle hash of the screen (small polling on `view-hierarchy.json`-style snapshot).
3. Calls `xcrun simctl io <UDID> screenshot <path>`.
4. Optionally resets to a known navigation root before the next entry.

Tooling: thin wrapper script in `tools/screenshots/` that invokes XcodeBuildMCP tools (`mcp__XcodeBuildMCP__tap`, `snapshot_ui`, `screenshot`) from a JSON-driven runner. No new SDK dependency.

This requires us to **add or audit accessibility identifiers** on the entry points of each captured screen. That work is part of this change's tasks.

### 7. Screen manifest: single JSON source of truth

`tools/screenshots/manifest.json`:

```json
{
  "locales": ["en", "fr"],
  "devices": [{ "name": "iPhone 16 Pro Max", "udid": "<resolved-at-runtime>" }],
  "screens": [
    {
      "id": "01_home",
      "filename": "01_home.png",
      "navigation": [{ "tap": "tab.home" }],
      "wait": "home.heroCarousel"
    },
    {
      "id": "05_settings_about_advanced",
      "filename": "05b_settings_about_advanced.png",
      "navigation": [{ "tap": "tab.settings" }, { "scrollTo": "settings.advanced" }],
      "wait": "settings.deleteAccountButton"
    }
    /* …one entry per screen */
  ]
}
```

The manifest is consumed by:

- The capture runner (drives navigation + filenames).
- `docs/SCREENSHOT_VERIFICATION.md` (lists what's expected to exist).
- A small CI sanity check (optional, future): "does every manifest entry have a file in `screenshots/<locale>/` for every locale?"

### 8. Atomic output: write to staging, then swap

The runner writes captures to `screenshots/.staging/<locale>/`. Only after the full manifest passes does it `rm -rf screenshots/<locale>/ && mv screenshots/.staging/<locale> screenshots/<locale>`. A failed run leaves the previous good set intact.

### 9. Audio Player screenshot: hydrate paused state, don't actually play

The Audio Player screen depends on `AudioService` + `IllustrationSyncManager` timers. In screenshot mode, the StoryViewModel is hydrated with a fixture story whose audio metadata has a known duration (e.g., 180s) and a "paused at 42s with illustration index 2" state. `AudioService` is replaced with a no-op fixture variant that exposes the same `@Published` state — no AVAudioEngine bring-up, no MP3 download.

## Risks / Trade-offs

- **[Risk]** Repository protocol gaps — `ReadingJourneyRepository` may not have a protocol today. → **Mitigation**: tasks include adding the protocol; production code remains source-compatible since the concrete class already exists.
- **[Risk]** Accessibility identifier coverage is incomplete in current views, making navigation brittle. → **Mitigation**: tasks include a sweep to add `accessibilityIdentifier(_)` on the manifest's wait/tap targets; this also benefits VoiceOver users.
- **[Risk]** Fixture content drifts from real production data shapes (e.g., new fields added to `Hero` after capture). → **Mitigation**: fixtures decode through the same `Hero`/`Story` model decoders so any schema change fails at fixture-load time, not at capture time.
- **[Risk]** Simulator locale changes don't fully propagate without a fresh erase. → **Mitigation**: capture script does `xcrun simctl erase` between locales by default, with a flag to skip for fast local iteration.
- **[Risk]** Bundled illustration PNGs inflate the app binary. → **Mitigation**: they're inside an asset catalog tagged for the `Debug` configuration's `Copy Bundle Resources` phase only; not present in `Release`. App Store binary is unaffected.
- **[Risk]** "Status bar always shows 9:41" requires `xcrun simctl status_bar override` — easy to forget. → **Mitigation**: capture script applies it once per simulator before the manifest loop and clears it on exit.
- **[Trade-off]** Mocked screens mean we can render UI states that don't match real backend behaviour (e.g., a Reading Journey with stats no real account has had time to accumulate). Acceptable — this is a marketing artefact pipeline, not a behaviour test.

## Migration Plan

Sequenced to keep `main` shippable at every step:

1. **Plumbing** (no user-visible change)
   - Add `-InfStoriesScreenshotMode` / `-InfStoriesScreenshotLocale` parsing.
   - Add `RepositoryFactory` selecting API vs fixture implementations.
   - Add `ReadingJourneyRepositoryProtocol` if missing; refactor injection sites.
2. **One screen end-to-end** (validation)
   - Build `FixtureHeroRepository` + `Resources/ScreenshotFixtures/{en,fr}/heroes.json`.
   - Verify Home tab renders correctly in both locales via launch args.
3. **Remaining fixtures + screen coverage**
   - Build out remaining `Fixture*` repositories and per-locale JSON.
   - Add accessibility identifiers to every manifest tap/wait target.
4. **Capture script + manifest**
   - Author `tools/screenshots/manifest.json` and `tools/screenshots/capture.sh` (wrapping XcodeBuildMCP-style automation).
   - Verify `./capture.sh en && ./capture.sh fr` produces complete sets.
5. **Regenerate and replace**
   - Delete `screenshots/en/` and `screenshots/fr/`, run the pipeline, commit new sets.
   - Tick `app-store-approval-fixes` task 5.2.

**Rollback:** Production behaviour is gated on `#if DEBUG` + launch arg. To roll back, do nothing — production never enters screenshot mode. To roll back the captured PNGs themselves, `git revert` the screenshots commit.

## Open Questions

- **Device matrix scope:** v1 captures one device (iPhone 16 Pro Max 6.9" — current App Store Connect required size). Should the manifest also generate iPad sizes? Default answer: no, until iPad is a marketed surface.
- **Where the screenshot user's first name lives:** is it acceptable to use generic names like "Lucas" (en) / "Léa" (fr), or should marketing pick branded names? Default: generic until marketing pushes back.
- **Status-bar time:** Apple's convention is `9:41`. Confirm `xcrun simctl status_bar override --time "9:41"` is sufficient and that we're OK with battery/wifi icons being shown as full.
- **Audio player paused-state visual:** confirm with design which illustration index + caption combo best represents the feature in stills.
- **CI:** do we want a `make screenshots-check` target that verifies manifest coverage on PR, or is local-only enough for v1? Default: local-only for v1.
