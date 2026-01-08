# Tasks: Limit Initial Release Languages

## Overview
Restrict language selection to English and French for v1.0 release while preserving all existing translations.

## Task List

### Phase 1: Core Language Filtering

- [x] **1. Add released languages configuration**
  - File: `Settings/AppSettings.swift`
  - Add `static let releasedLanguageCodes: Set<String> = ["en", "fr"]`
  - Add `static let releasedLanguageNames: Set<String> = ["English", "French"]`
  - Add computed property `releasedLanguages` that filters `availableLanguages`
  - Keep original `availableLanguages` array unchanged for future use

- [x] **2. Filter story language picker**
  - File: `Views/Settings/SettingsView.swift`
  - Update story language Picker to use `AppSettings.releasedLanguages` instead of `AppSettings.availableLanguages`
  - Verify picker shows only "English" and "French"

- [x] **3. Filter UI language picker**
  - File: `Utilities/LocalizationManager.swift`
  - Add `static let releasedUILanguages: [UILanguage] = [.system, .english, .french]`
  - File: `Views/Settings/SettingsView.swift`
  - Update UI language Picker to use `LocalizationManager.releasedUILanguages` instead of `UILanguage.allCases`
  - Verify picker shows only "System Default", "English", and "French"

### Phase 2: Default Language Handling

- [x] **4. Update default language fallback**
  - File: `Settings/AppSettings.swift`
  - Modify `languageCodeToSupported()` to return "English" for es, de, it (not released)
  - Ensure Spanish/German/Italian device users default to English
  - Add code comment explaining phased release strategy

- [x] **5. Validate stored preference on app launch**
  - File: `Settings/AppSettings.swift`
  - In `init()`, check if stored `preferredLanguage` is in `releasedLanguageNames`
  - If not (e.g., user had Spanish selected), reset to English
  - Log when language preference is reset for debugging

### Phase 3: Verification

- [x] **6. Verify story generation language flow**
  - Confirm `StoryViewModel.generateStory()` passes correct language to repository
  - Confirm `StoryRepository.generateStory()` sends language to backend API
  - Confirm backend generates story in requested language (English or French)
  - Test: Generate story in French, verify French content returned

- [x] **7. Verify audio generation language flow**
  - Confirm `StoryRepository.generateAudio()` sends correct language
  - Confirm audio is narrated in the selected language
  - Test: Generate French audio, verify French narration

- [x] **8. Test UI language override**
  - Test selecting French UI language triggers restart prompt
  - Test app displays French UI after restart
  - Test "System Default" follows device language (if en/fr) or falls back to English

### Phase 4: Edge Cases

- [x] **9. Handle existing users with non-released language preference**
  - If user previously selected Spanish/German/Italian, gracefully migrate to English
  - Show no error to user, just use English
  - Preference is automatically updated on next settings save

- [x] **10. Document preserved translations**
  - Add code comment in `AppSettings.swift` explaining:
    - Spanish, German, Italian translations are preserved
    - To enable: add language code to `releasedLanguageCodes`
    - String Catalogs and PromptLocalizer already support all 5 languages

## Dependencies
- None - changes are isolated to iOS client

## Parallelizable Work
- Tasks 1-3 can be done together (core filtering)
- Tasks 4-5 can follow (default handling)
- Tasks 6-8 are verification (sequential testing)
- Tasks 9-10 are polish (can parallel with verification)

## Validation Checklist
- [x] Build succeeds with no warnings
- [x] Story language picker shows only English, French
- [x] UI language picker shows only System, English, French
- [x] French story generates French content
- [x] English story generates English content
- [x] Device set to Spanish defaults to English
- [x] Spanish/German/Italian translations remain in xcstrings files
- [x] PromptLocalizer still has all 5 language templates
