## Why

The current App Store screenshot set is generated from a single shared demo account, so user-generated content (hero names, custom event titles, story titles) bleeds across locales — French strings appear in `screenshots/en/*.png` and vice versa. This blocks task 5.2 of `app-store-approval-fixes` and is a concrete App Store rejection risk: Apple expects locale-appropriate content in each locale's screenshot set. We need a reproducible, locale-correct capture pipeline before the next submission.

## What Changes

- Introduce a **screenshot-mode build configuration** (debug-only) that hydrates the UI from local, locale-specific fixtures instead of calling the backend, eliminating cross-account contamination and network flakiness during capture.
- Add **per-locale fixture files** for the en and fr locales: hero, custom event(s), at least one generated story with a localized title, and any required preferences (app language, theme).
- Add an **`xcrun simctl` / XcodeBuildMCP-driven capture script** that, for each `(locale, device)` pair, configures the simulator locale + region, launches the app in screenshot mode with the matching fixture, drives through the screen list, and writes deterministically-named PNGs to `screenshots/<locale>/`.
- Define the **required screenshot manifest** (filenames and the screens they map to) so EN and FR sets stay in lockstep and missing slots are caught in CI.
- Replace the existing `screenshots/en/` and `screenshots/fr/` sets by re-running the new pipeline. Old captures are deleted, not edited.
- Restrict v1 scope to **English and French only** (mirrors `AppSettings.releasedLanguageCodes`); pipeline structure is extensible to ES/DE/IT later but those locales are explicitly out of scope here.

## Capabilities

### New Capabilities
- `localized-screenshot-pipeline`: Reproducible, per-locale App Store screenshot capture using a debug-only screenshot-mode build, local fixture files, and an `xcrun simctl`-driven capture script. Covers the fixture format, the screenshot-mode flag contract, the screen manifest, and the locale/region setup performed before each capture run.

### Modified Capabilities
- `app-store-metadata`: Add requirements that App Store screenshots for a given locale MUST contain only that locale's strings (no user-content cross-contamination), that the captured screen set MUST match a documented manifest, and that the capture process MUST be reproducible from a clean checkout.

## Impact

- **iOS app — new build configuration / launch arguments**: A screenshot-mode entry point that swaps `HeroRepository`, `StoryRepository`, and `CustomEventRepository` for fixture-backed implementations behind a compile-time or launch-argument flag. Production behavior is unchanged.
- **Repositories**: Repository protocols must be cleanly substitutable so a fixture-backed variant can stand in without touching call sites. Existing API-only contract is preserved for non-screenshot builds.
- **New directory `screenshot-fixtures/`** (or similar): JSON or Swift-defined fixtures per locale (`en/`, `fr/`), each containing hero, custom event(s), story content, and any preferences needed to reach every screen in the manifest.
- **New capture script** under `tools/screenshots/` (or `scripts/`): bash/Swift script invoking `xcrun simctl` for locale/region setup, app launch with screenshot-mode args, and UI navigation via XcodeBuildMCP-style automation. Outputs to `screenshots/<locale>/`.
- **Existing screenshot folders**: `screenshots/en/` and `screenshots/fr/` are wiped and regenerated. Filenames in the new manifest may differ from current names — App Store Connect upload step must be re-checked.
- **`docs/SCREENSHOT_VERIFICATION.md`**: Updated to point at the new pipeline as the source of truth; the cross-contamination callout becomes historical context.
- **`app-store-approval-fixes` change (task 5.2)**: Unblocked once this pipeline produces a clean set; can then be ticked and archived.
- **CI (optional, not in v1 scope)**: The capture script is reproducible enough to run on a CI mac runner later, but v1 only requires local reproducibility.
- **Backend**: No changes. Mock-mode bypasses the backend entirely during capture.

## Non-goals

- Hosting the captured screenshots or automating App Store Connect upload — manual upload remains, only generation is automated.
- Supporting locales beyond English and French in v1. The fixture/manifest format must be extensible to ES/DE/IT, but those locales are not delivered here.
- Reworking the production repository layer or introducing a runtime feature-flag system. Screenshot mode is a build/launch-arg switch, not a user-facing toggle.
- Migrating the rest of the app to use fixtures for unit or integration tests (the existing `testing` spec is unaffected). Fixtures here exist solely for the capture pipeline.
- Building a CI pipeline for screenshot diffs or visual regression. Out of scope.
- Replacing or evaluating Fastlane snapshot. Decision already made in favor of `xcrun simctl` + XcodeBuildMCP.
