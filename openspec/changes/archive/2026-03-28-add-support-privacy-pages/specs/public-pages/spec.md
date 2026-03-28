## ADDED Requirements

### Requirement: Privacy Policy Page
The website SHALL provide a COPPA-compliant privacy policy at `/[locale]/privacy` accessible without authentication.

#### Scenario: Privacy policy is accessible in English
- **WHEN** a user navigates to `/en/privacy`
- **THEN** a privacy policy page is displayed in English
- **AND** it covers: data collection, AI processing (OpenAI), children's privacy, data retention, account deletion
- **AND** it includes contact info (support@infinitestories.app)
- **AND** the effective date is displayed

#### Scenario: Privacy policy is accessible in French
- **WHEN** a user navigates to `/fr/privacy`
- **THEN** the same privacy policy is displayed fully translated in French

### Requirement: Terms of Service Page
The website SHALL provide terms of service at `/[locale]/terms` accessible without authentication.

#### Scenario: Terms page is accessible
- **WHEN** a user navigates to `/en/terms` or `/fr/terms`
- **THEN** terms of service are displayed in the appropriate language
- **AND** it covers: service description, acceptable use, AI content disclaimer, subscription terms, liability

### Requirement: Support Page
The website SHALL provide a support page at `/[locale]/support` with FAQ and troubleshooting.

#### Scenario: Support page provides help resources
- **WHEN** a user navigates to `/en/support` or `/fr/support`
- **THEN** the page displays contact email, FAQ section, and troubleshooting guides
- **AND** content is in the appropriate language

### Requirement: Locale-Based Routing
All public pages SHALL support English and French via path-based locale segments.

#### Scenario: Root redirects to default locale
- **WHEN** a user navigates to `/`
- **THEN** they are redirected to `/en`

#### Scenario: Language switcher changes locale
- **WHEN** a user clicks the FR/EN language switcher in the navigation
- **THEN** the page reloads in the selected language
- **AND** the URL path updates to reflect the new locale

### Requirement: Landing Page
The website SHALL provide a marketing landing page at `/[locale]` with App Store download links.

#### Scenario: Landing page displays all sections
- **WHEN** a user navigates to `/en` or `/fr`
- **THEN** the page displays: hero section, features, how it works, testimonials, FAQ, and footer
- **AND** all text is in the appropriate language
- **AND** App Store download links are functional
