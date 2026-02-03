## ADDED Requirements

### Requirement: In-App Privacy Policy Link
The SettingsView About section SHALL include a tappable link to the Privacy Policy URL.

#### Scenario: User taps Privacy Policy link
- **WHEN** user taps "Privacy Policy" in the Settings About section
- **THEN** the system opens `https://www.infinitestories.app/privacy` in Safari or an in-app browser

### Requirement: In-App Terms of Service Link
The SettingsView About section SHALL include a tappable link to the Terms of Service URL.

#### Scenario: User taps Terms of Service link
- **WHEN** user taps "Terms of Service" in the Settings About section
- **THEN** the system opens `https://www.infinitestories.app/terms` in Safari or an in-app browser

### Requirement: Legal Links Accessibility
Both legal links SHALL meet WCAG AA accessibility requirements.

#### Scenario: VoiceOver reads legal links
- **WHEN** VoiceOver focus lands on a legal link
- **THEN** it reads the link label (e.g., "Privacy Policy") and identifies it as a link
- **AND** minimum touch target is 44pt

### Requirement: Legal Links Localized
Legal link labels SHALL be localized in all supported app languages.

#### Scenario: French user sees localized labels
- **WHEN** app language is French
- **THEN** Privacy Policy link reads "Politique de confidentialité"
- **AND** Terms of Service link reads "Conditions d'utilisation"
