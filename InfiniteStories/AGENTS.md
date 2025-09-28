# Repository Guidelines

## Project Structure & Module Organization
- Core SwiftUI app lives in `InfiniteStories/`, with feature folders for `Views`, `ViewModels`, `Models`, and `Utilities`.
- Reusable services sit in `InfiniteStories/Services` (AI orchestration, audio, background tasks, logging) and drive most business logic.
- Assets sit in `InfiniteStories/Assets.xcassets`; feature flags live in `AppConfiguration.swift`.
- Unit and integration tests live in `InfiniteStoriesTests/`, while UI smoke tests are in `InfiniteStoriesUITests/`.

## Build, Test, and Development Commands
- `xcodebuild -scheme InfiniteStories -destination 'platform=iOS Simulator,name=iPhone 15' build` performs a clean command-line build.
- `xcodebuild test -scheme InfiniteStories -destination 'platform=iOS Simulator,name=iPhone 15'` runs the XCTest and UI test targets.
- `swift run swiftformat .` (if installed) formats Swift sources before committing.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines: `UpperCamelCase` for types, `lowerCamelCase` for properties, and prefer domain-specific identifiers (e.g., `IllustrationSyncManager`).
- Maintain 4-space indentation, keep imports tight, and leverage `// MARK:` pragmas to organize large files as in `InfiniteStoriesApp.swift`.
- Mirror existing folder separation when adding files; avoid dropping new code at the root of `InfiniteStories/`.

## Testing Guidelines
- Use XCTest with `@testable import InfiniteStories`; colocate specs next to the module they validate (service tests in `InfiniteStoriesTests/Services` if added).
- Name tests in behavior form (`testAudioSessionConfiguration`) and document edge cases with inline comments, matching the style in `AudioServiceIdleTimerTests.swift`.
- Prefer lightweight fakes over live network calls; stub AI responses so tests stay deterministic.
- Run full `xcodebuild test` before opening a pull request and ensure new features add meaningful coverage for services and view models.

## Commit & Pull Request Guidelines
- Follow the repository’s imperative, descriptive commit style, optionally prefixed with an emoji for quick scanning (e.g., `📚 Refresh documentation`).
- Write focused commits that combine code, tests, and docs for a single concern; avoid multi-feature dumps.
- Pull requests should include a clear summary, linked issue (if any), simulator target, and screenshots or recordings for UI updates.
- List manual verification steps (simulator, device, accessibility checks) so reviewers can confirm behavior quickly.

## Configuration & Security Notes
- Never commit API keys; set the OpenAI credential through the in-app settings view, which persists securely via `KeychainHelper`.
- When adding new network calls, route them through `NetworkService` to inherit background handling and logging.
- Document any new background tasks or feature flags in `AppConfiguration.swift` and the relevant architecture notes to keep the knowledge base current.
