# app-store-metadata Specification

## Purpose
TBD - created by archiving change update-app-store-metadata-v101. Update Purpose after archive.
## Requirements
### Requirement: Metadata Language Claims Must Match Released Languages
App Store metadata documentation MUST accurately reflect the languages supported in the current release version to avoid App Review rejection and user disappointment. Review notes MUST include demo account credentials and instructions for testing all major flows.

#### Scenario: Version 1.0.1 with English and French only
Given the app is at version 1.0.1
And the released languages are English and French only (per AppSettings.releasedLanguageCodes)
When reviewing App Store metadata documentation
Then all language support claims reference "English and French" or "2 languages"
And claims of "5 languages" do not appear for v1.0.1 content
And deferred languages (Spanish, German, Italian) are marked as "Future Release"

#### Scenario: Review notes include demo account
- **WHEN** submitting to App Store Connect
- **THEN** the Review Notes field includes a demo account username and password
- **AND** includes step-by-step instructions to test: hero creation, story generation, audio playback, and account deletion
- **AND** credentials are valid and functional at submission time

### Requirement: What's New Section Must Match Current Version
App Store "What's New" content MUST reference the correct version number and describe only features available in that version.

#### Scenario: Updating What's New for v1.0.1
Given a release is prepared at version 1.0.1
When updating the App Store metadata
Then the "What's New" section references "Version 1.0.1"
And the content describes features actually available in v1.0.1
And promotional text aligns with the version's capabilities

