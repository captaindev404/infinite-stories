# ios-localization Spec Delta

## MODIFIED Requirements

### Requirement: UI Localization Support

The iOS app MUST support full UI localization. Initial release (v1.0) includes English and French. Additional languages (Spanish, German, Italian) will be enabled in future releases.

#### Scenario: Display localized UI for English-speaking user

- **WHEN** user's device language is English
- **THEN** all UI text displays in English
- **AND** navigation titles are localized
- **AND** button labels are localized
- **AND** error messages are localized
- **AND** accessibility labels are localized

#### Scenario: Display localized UI for French-speaking user

- **WHEN** user's device language is French
- **THEN** home screen displays French text
- **AND** hero creation wizard shows French instructions
- **AND** story generation shows French prompts
- **AND** settings screen shows French labels

#### Scenario: Fallback to English for unsupported language

- **WHEN** user's device language is not English or French
- **THEN** all UI text displays in English as fallback
- **AND** app functions normally without crashes
- **AND** user can manually select French if preferred

### Requirement: Language Override Setting

The app MUST allow users to override UI language independently of device settings, limited to released languages.

#### Scenario: User selects specific UI language

- **WHEN** user opens Settings
- **AND** selects "UI Language" option
- **THEN** picker shows "System Default", "English", and "French"
- **AND** selecting a specific language stores the preference
- **AND** app prompts user to restart for changes to take effect

#### Scenario: User selects story generation language

- **WHEN** user opens Settings
- **AND** views story language picker
- **THEN** picker shows only "English" and "French"
- **AND** stories generate in the selected language
- **AND** audio is synthesized in the matching language

## ADDED Requirements

### Requirement: Phased Language Release

Languages MUST be released in phases, with translations preserved in codebase for future enablement.

#### Scenario: Initial release language set

- **GIVEN** app version 1.0
- **WHEN** user views language options
- **THEN** only English and French are selectable
- **AND** Spanish, German, Italian translations exist in String Catalogs
- **AND** PromptLocalizer retains all language templates

#### Scenario: Story language matches UI language availability

- **WHEN** user selects story language
- **THEN** available options match UI language options (English, French)
- **AND** generated story content is in selected language
- **AND** audio narration matches story language

#### Scenario: Future language enablement

- **GIVEN** translations for Spanish are validated
- **WHEN** developer enables Spanish in `releasedLanguages`
- **THEN** Spanish appears in both UI and story language pickers
- **AND** no new translation work is required
- **AND** existing Spanish translations are used immediately
