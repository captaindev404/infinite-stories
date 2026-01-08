# ios-localization Specification

## Purpose
TBD - created by archiving change add-ui-localization. Update Purpose after archive.
## Requirements
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

### Requirement: Localized Strings File Structure

The app MUST use Apple's standard localization system with .lproj folders.

#### Scenario: Proper localization file organization

- **WHEN** the app is built
- **THEN** project contains en.lproj, es.lproj, fr.lproj, de.lproj, it.lproj folders
- **AND** each folder contains Localizable.strings
- **AND** each folder contains InfoPlist.strings
- **AND** strings use category-prefixed keys (e.g., "home.title")

#### Scenario: Translator comments for context

- **WHEN** translator reviews Localizable.strings
- **THEN** each string group has a comment explaining context
- **AND** placeholder strings document expected values
- **AND** character limit warnings are included where relevant

### Requirement: Dynamic String Localization

The app MUST properly localize dynamically constructed strings.

#### Scenario: Localize strings with interpolation

- **WHEN** displaying "You have 3 heroes"
- **THEN** use proper localization with format specifiers
- **AND** handle pluralization correctly per language
- **AND** string order adapts to language grammar

#### Scenario: Localize enum display names

- **WHEN** displaying CharacterTrait options (Brave, Kind, etc.)
- **THEN** each trait name is localized
- **AND** trait descriptions are localized
- **AND** StoryEvent names are localized

### Requirement: Localized Info.plist

The app MUST localize system-facing strings in Info.plist.

#### Scenario: Localized permission descriptions

- **WHEN** app requests camera permission on Spanish device
- **THEN** permission dialog shows Spanish explanation
- **AND** photo library permission shows Spanish text
- **AND** app display name shows in device language

### Requirement: Accessibility Localization

All accessibility labels and hints MUST be localized.

#### Scenario: VoiceOver reads localized content

- **WHEN** VoiceOver user navigates the app in German
- **THEN** all accessibility labels are spoken in German
- **AND** button actions are described in German
- **AND** image descriptions are localized

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

