## ADDED Requirements

### Requirement: Screenshot Mode Activation

The iOS app SHALL provide a screenshot-mode entry point that is activated by launch arguments at runtime. The entry point MUST be compiled into Debug builds only and MUST be absent from Beta (TestFlight) and Release (App Store) binaries.

#### Scenario: Screenshot mode opt-in via launch arguments
- **WHEN** the app is launched with `-InfStoriesScreenshotMode YES` and `-InfStoriesScreenshotLocale en` (or `fr`)
- **THEN** the app boots into screenshot mode using fixture-backed repositories
- **AND** no network request is made to the backend during the session
- **AND** the requested locale is applied to the UI

#### Scenario: Screenshot mode is absent from release builds
- **WHEN** the app is compiled with the Release or Beta configuration
- **THEN** the screenshot-mode entry point is excluded by `#if DEBUG` and is not present in the produced binary
- **AND** any launch argument requesting screenshot mode is silently ignored

#### Scenario: Default behavior unchanged
- **WHEN** the app is launched without screenshot-mode arguments
- **THEN** all repositories use their production API-backed implementations
- **AND** the authentication flow operates normally

### Requirement: Fixture-Backed Repositories

When screenshot mode is active, the app SHALL substitute fixture-backed implementations for all repositories that drive captured screens. The substitutes MUST conform to the same protocols as the API-backed implementations so call sites are unchanged.

#### Scenario: Hero repository substitution
- **WHEN** screenshot mode is active
- **THEN** the Hero data path is served by a `FixtureHeroRepository` conforming to `HeroRepositoryProtocol`
- **AND** the fixture data is loaded from the bundled JSON for the active locale
- **AND** no call is made to `/api/v1/heroes`

#### Scenario: Story repository substitution
- **WHEN** screenshot mode is active
- **THEN** the Story data path is served by a `FixtureStoryRepository` conforming to `StoryRepositoryProtocol`
- **AND** no call is made to story generation, audio, or illustration endpoints

#### Scenario: Custom event repository substitution
- **WHEN** screenshot mode is active
- **THEN** the Custom Event data path is served by a `FixtureCustomEventRepository` conforming to `CustomEventRepositoryProtocol`

#### Scenario: Reading journey repository substitution
- **WHEN** screenshot mode is active
- **THEN** the Reading Journey data path is served by a fixture implementation conforming to `ReadingJourneyRepositoryProtocol`
- **AND** chart series and milestone counts are read from the locale's fixture file

### Requirement: Authentication Bypass in Screenshot Mode

When screenshot mode is active, the app SHALL present an authenticated state without contacting the auth backend, calling Keychain, or running token-refresh timers.

#### Scenario: Synthetic authenticated session
- **WHEN** the app launches in screenshot mode
- **THEN** `AuthStateManager` reports `isAuthenticated = true` and `sessionExpired = false`
- **AND** the root view is `MainTabView` (not `AuthenticationView`)
- **AND** no network request is made to any authentication endpoint

#### Scenario: No Keychain interaction
- **WHEN** screenshot mode is active
- **THEN** the app does not read or write authentication tokens to the Keychain

### Requirement: Per-Locale Fixture Files

Fixture data SHALL be provided per supported locale and SHALL render the UI exclusively in that locale's strings. Fixtures MUST decode through the same Swift model types as production data so that schema drift is detected at fixture-load time.

#### Scenario: Locale-specific content
- **WHEN** the active screenshot locale is `fr`
- **THEN** every user-generated string visible in the UI (hero names, custom event titles, story titles) is in French
- **AND** no string from the `en` fixture set is rendered

#### Scenario: Model compatibility
- **WHEN** a fixture file is loaded
- **THEN** it decodes through the same `Codable` types used by the API client
- **AND** any required field absent from the fixture causes a fatal load-time error (not a silent fallback)

#### Scenario: Bundled image assets
- **WHEN** a captured screen references an avatar or illustration
- **THEN** the asset is loaded from a bundled PNG packaged with the locale's fixture set
- **AND** no DALL·E or remote image request is made

### Requirement: Screen Manifest Drives Capture

A single manifest file SHALL declare the complete set of screens to capture, the navigation steps to reach each one, and the output filename. The manifest MUST be the source of truth for both the capture script and the verification checklist.

#### Scenario: Manifest defines coverage
- **WHEN** the capture pipeline runs
- **THEN** it captures exactly the screens listed in `tools/screenshots/manifest.json`
- **AND** it produces one PNG per `(locale, screen)` pair
- **AND** filenames match the `filename` field in the manifest entry

#### Scenario: Manifest coverage parity
- **WHEN** the manifest is read
- **THEN** every screen entry applies to every supported locale equally
- **AND** there is no locale-specific screen list

#### Scenario: Navigation by accessibility identifier
- **WHEN** the capture script navigates to a screen
- **THEN** it uses accessibility identifiers declared on view elements, not coordinate taps or string matching on visible labels

### Requirement: Reproducible Capture from Clean Checkout

The capture pipeline SHALL be runnable from a clean checkout with no manual data entry. A single invocation per locale MUST produce a complete, deterministic screenshot set.

#### Scenario: One command per locale
- **WHEN** the maintainer runs the documented capture command for locale `en`
- **THEN** a complete `screenshots/en/` set is produced matching the manifest
- **AND** no manual taps or text entry are required during the run

#### Scenario: Deterministic output
- **WHEN** the capture is run twice on the same machine without code or fixture changes
- **THEN** the resulting PNGs are byte-identical (or differ only in known nondeterministic regions such as antialiasing)

#### Scenario: Status bar normalization
- **WHEN** a screenshot is captured
- **THEN** the simulator status bar shows `9:41` time, full battery, and full signal
- **AND** no debug overlays, charging indicator, or low-battery glyph are present

### Requirement: Atomic Output Replacement

The capture pipeline SHALL write screenshots to a staging directory and SHALL only replace the canonical `screenshots/<locale>/` directory after the full manifest succeeds for that locale.

#### Scenario: Successful run replaces the set
- **WHEN** the capture run for a locale completes with every manifest entry captured
- **THEN** `screenshots/<locale>/` is replaced with the staged set atomically
- **AND** no stale files from a previous run remain

#### Scenario: Failed run preserves previous set
- **WHEN** the capture run fails mid-manifest
- **THEN** `screenshots/<locale>/` retains its previous contents unchanged
- **AND** the staging directory is left in place for debugging

### Requirement: Locale Scope and Extensibility

The pipeline SHALL initially support English and French only, matching `AppSettings.releasedLanguageCodes`. Adding a new supported locale MUST require only the addition of a fixture folder and a manifest locale entry, with no architectural change.

#### Scenario: V1 locale set
- **WHEN** the pipeline is invoked without a locale argument or with `all`
- **THEN** captures are produced for `en` and `fr` only
- **AND** no captures are produced for `es`, `de`, or `it` in v1

#### Scenario: Adding a future locale
- **WHEN** a maintainer adds `screenshot-fixtures/es/` with the required fixture files and lists `es` in `manifest.json`
- **THEN** the pipeline produces a complete `screenshots/es/` set on the next run
- **AND** no Swift source changes to the screenshot mode plumbing are required
