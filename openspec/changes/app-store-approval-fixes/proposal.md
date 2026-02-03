## Why

The app cannot pass Apple App Store review in its current state. An audit against Apple's approval requirements revealed 7 issues across privacy, account management, and UI completeness. These are not enhancements — they are blockers that will cause rejection.

## What Changes

- **BREAKING**: Add backend account deletion endpoint and in-app "Delete Account" UI in Settings
- Add Privacy Policy and Terms of Service links to the Settings About section
- Host real Privacy Policy and Terms of Service pages at public URLs
- Remove or hide PictogramGenerationView — contains "coming soon" text that triggers rejection
- Replace "Illustration Coming Soon" placeholder with a loading/generating indicator
- Prepare App Store Connect review notes with demo account credentials
- Resolve 6 TODO gaps in backend integration (play count, favorite stories, story count per hero)

## Capabilities

### New Capabilities
- `account-deletion`: Backend endpoint and in-app UI for full account deletion (server + local data)
- `legal-pages`: Privacy Policy and Terms of Service hosted pages and in-app links

### Modified Capabilities
- `app-store-metadata`: Add demo account credentials to review notes, ensure screenshots reflect final UI
- `custom-events`: Remove or gate PictogramGenerationView to eliminate "coming soon" text
- `ios-integration`: Replace illustration "coming soon" placeholder with loading state
- `reading-journey`: Resolve TODO for favorite stories backend endpoint
- `ios-viewmodel-architecture`: Resolve TODO for play count and story count API integration

## Impact

- **Backend API**: New `DELETE /api/v1/user/account` endpoint required
- **Settings UI**: New Delete Account button, new Privacy/Terms links in About section
- **Custom Events flow**: PictogramGenerationView removed or hidden from navigation
- **Illustration carousel**: Placeholder view text changed from "coming soon" to loading indicator
- **Infrastructure**: Two new public web pages (privacy policy, terms of service) need hosting
- **App Store Connect**: Review notes field updated with test credentials and flow instructions
- **StoryViewModel / HeroRepository**: Wire up missing API calls for play count and story count
- **ReadingJourneyView**: Wire up or remove favorite stories section pending backend endpoint
