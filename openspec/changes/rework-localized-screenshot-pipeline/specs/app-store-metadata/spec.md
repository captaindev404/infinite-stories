## ADDED Requirements

### Requirement: Screenshot Locale Purity

App Store screenshots uploaded for a given locale MUST contain only strings from that locale. User-generated content (hero names, custom event titles, story titles), system chrome, and app UI strings MUST all match the screenshot's target locale. No cross-contamination between locale sets is permitted.

#### Scenario: English screenshot set contains only English strings
- **WHEN** any file under `screenshots/en/` is inspected
- **THEN** every visible string in the image is in English
- **AND** no French, Spanish, German, or Italian strings appear

#### Scenario: French screenshot set contains only French strings
- **WHEN** any file under `screenshots/fr/` is inspected
- **THEN** every visible string in the image is in French
- **AND** no English string appears (excluding proper nouns and brand names)

#### Scenario: User-generated content matches locale
- **WHEN** a screenshot includes user-generated content (hero name, custom event title, story title)
- **THEN** that content is in the same locale as the rest of the screen
- **AND** content was produced by a fixture or account dedicated to that locale, not shared across locales

### Requirement: Screenshot Manifest Coverage Parity

The set of captured screens MUST be identical across all supported locales. Every screen present in one locale's screenshot folder MUST be present in every other supported locale's folder, and no locale-only screens are permitted.

#### Scenario: Equal screen count per locale
- **WHEN** the canonical screenshot directories are listed
- **THEN** `screenshots/en/` and `screenshots/fr/` contain the same number of files
- **AND** the set of filenames is identical between the two directories

#### Scenario: Manifest is the source of truth
- **WHEN** a new screen is added to the App Store submission
- **THEN** an entry is added to `tools/screenshots/manifest.json`
- **AND** the next capture run produces the corresponding file in every supported locale's folder

### Requirement: Reproducible Screenshot Capture

The process for producing the App Store screenshot set MUST be reproducible from a clean checkout, with no manual data entry, no shared account dependencies, and no live backend dependency. The capture procedure MUST be documented.

#### Scenario: Documented capture command
- **WHEN** a maintainer reads `docs/SCREENSHOT_VERIFICATION.md` (or successor)
- **THEN** the document specifies the exact command(s) to regenerate the screenshot set for any supported locale
- **AND** the procedure does not require a backend account, database state, or manual UI input

#### Scenario: Capture runs offline
- **WHEN** the capture pipeline is invoked
- **THEN** it completes successfully with no network connectivity
- **AND** no request is made to the InfiniteStories backend, OpenAI, or any other remote service

#### Scenario: Old shared-account captures are retired
- **WHEN** the App Store screenshot set is regenerated for a submission
- **THEN** the new captures fully replace any previous captures produced by a shared cross-locale account
- **AND** no screenshot produced by the legacy shared-account method remains in `screenshots/<locale>/`
