## 1. Account Deletion

- [x] 1.1 Add `case deleteAccount` to `Endpoint.swift` mapped to `DELETE /api/v1/user/account`
- [x] 1.2 Add `deleteAccount()` method to a user/account repository that calls the endpoint
- [x] 1.3 Add "Delete Account" button to SettingsView Advanced section (red destructive style, below "Erase All Data")
- [x] 1.4 Add two-step confirmation dialog: first alert explaining consequences, then destructive "Delete My Account" confirmation
- [x] 1.5 Wire confirmation to API call → on 204 success, run existing `eraseAllData()` then sign out and navigate to auth screen
- [x] 1.6 Handle API failure: show error alert with retry, do not erase local data
- [x] 1.7 Add localized strings for delete account button, confirmation dialog, and error messages (English + French)

## 2. Legal Links in Settings

- [x] 2.1 Add SwiftUI `Link` for "Privacy Policy" pointing to `https://www.infinitestories.app/privacy` in SettingsView About section
- [x] 2.2 Add SwiftUI `Link` for "Terms of Service" pointing to `https://www.infinitestories.app/terms` in SettingsView About section
- [x] 2.3 Add localized strings for both link labels (English + French)
- [x] 2.4 Verify VoiceOver reads links correctly and touch targets are 44pt minimum

## 3. Remove "Coming Soon" Text

- [x] 3.1 Remove or gate navigation path to `PictogramGenerationView` in the custom event creation flow so the view is unreachable
- [x] 3.2 In `IllustrationCarouselView.placeholderView()`, replace "Illustration Coming Soon" text and icon with a `ProgressView` and "Generating illustration..." label
- [x] 3.3 Update localized strings: remove `customEvent.pictogram.comingSoon` usage, add `illustration.carousel.generating` key (English + French)

## 4. Wire Up TODO API Integrations

- [x] 4.1 Add `updatePlayCount` endpoint to `Endpoint.swift` (e.g., `POST /api/v1/stories/{id}/play`)
- [x] 4.2 Call play count endpoint from StoryViewModel after playback completes (replace TODO at `StoryViewModel.swift:562`)
- [x] 4.3 Wire `storyCount` from backend hero list response through `HeroRepository` to views (replace hardcoded `storyCount: 0` in `HeroListView.swift:108` and `HeroSelectionForStoryView.swift:90`)
- [x] 4.4 Hide favorite stories section in `ReadingJourneyView` entirely (remove the section, not just empty state) until backend endpoint exists

## 5. App Store Connect Preparation

- [ ] 5.1 Document demo account credentials and step-by-step testing instructions for App Store Review Notes
- [ ] 5.2 Verify all screenshots reflect final UI (no "coming soon" text, legal links visible in Settings)
