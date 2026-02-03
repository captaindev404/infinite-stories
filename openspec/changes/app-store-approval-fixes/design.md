## Context

The app fails Apple App Store review due to missing privacy/legal links, no account deletion, and "coming soon" placeholder text. The backend is a REST API; the iOS app has no local persistence for Hero/Story data. SettingsView exists with an "Erase All Data" button (local only) and an About section with no legal links. PictogramGenerationView is a placeholder with "coming soon" text. IllustrationCarouselView shows "Illustration Coming Soon" when images aren't ready. Several ViewModels use hardcoded `storyCount: 0` and TODO comments for missing API calls.

## Goals / Non-Goals

**Goals:**
- Pass Apple App Store review on first submission
- Add account deletion (backend + iOS) per Apple requirement
- Add Privacy Policy and Terms of Service links in-app
- Remove all "coming soon" / placeholder text from user-facing UI
- Wire up remaining TODO API integrations (play count, story count)

**Non-Goals:**
- Hosting the actual privacy policy / ToS web pages (infrastructure task, not iOS)
- Implementing pictogram generation — just hiding the unfinished view
- Implementing favorite stories backend endpoint — just hiding the UI section
- Redesigning Settings UI beyond adding required links and delete button

## Decisions

### 1. Account Deletion: Server-first, then local wipe

Add `case deleteAccount` to `Endpoint.swift` → `DELETE /api/v1/user/account`. On confirmation, call the API first. Only erase local data after 204 response. If the API fails, show error and do not erase local data. This prevents data loss when the server can't confirm deletion.

**Alternative considered:** Local wipe first, then API call. Rejected because if the API fails, the user loses local data but their server account persists — worst of both worlds.

### 2. Legal links: Safari via `Link` view, not in-app browser

Use SwiftUI `Link` to open Privacy Policy and Terms of Service URLs in Safari. Simpler than `SFSafariViewController`, no extra imports, and Apple reviewers can verify the URLs load in Safari.

**Alternative considered:** `SFSafariViewController` for in-app browsing. Unnecessary complexity for static legal pages.

### 3. PictogramGenerationView: Remove navigation entry point

Remove or `#if false` the navigation path to PictogramGenerationView in the custom event flow. Keep the file for future use but make it unreachable. This is faster and safer than deleting the view.

### 4. Illustration placeholder: Replace text, keep view structure

Change `IllustrationCarouselView.placeholderView()` to show a `ProgressView` with "Generating illustration..." instead of "Illustration Coming Soon". The view structure stays the same; only the label and icon change.

### 5. TODO API gaps: Wire up or hide

- **Play count**: Add `updatePlayCount` endpoint to `Endpoint.swift`, call from ViewModel after playback completes.
- **Story count per hero**: Backend already returns `storyCount` in hero list response — wire it through `HeroRepository` to the views instead of hardcoding `0`.
- **Favorite stories**: Hide the section in `ReadingJourneyView` entirely until the backend endpoint exists. No empty state, no placeholder.

### 6. Delete Account button placement

Place "Delete Account" in Settings → Advanced section, below the existing "Erase All Data" button. Red destructive style. Two-step confirmation: first an alert explaining consequences, then a second confirmation with "Delete My Account" destructive button.

## Risks / Trade-offs

- **Backend endpoint not ready** → iOS can ship the UI and endpoint definition, but the feature won't work until backend deploys `DELETE /api/v1/user/account`. Mitigation: coordinate backend deploy before App Store submission.
- **Legal pages not hosted** → Links will 404 if pages aren't published. Mitigation: verify URLs resolve before submitting to App Store Connect.
- **Hiding favorite stories** → Reduces Reading Journey content. Acceptable for v1; tracked as separate future work.
- **Hardcoded story count fix depends on backend response shape** → If backend doesn't return `storyCount` in hero list, need a separate endpoint. Mitigation: check actual API response before implementing.

## Open Questions

- Does the backend already return `storyCount` in the hero list response, or is a new field needed?
- Who hosts the privacy policy and ToS pages — engineering or marketing?
- Should the demo review account be a permanent test account or created per submission?
