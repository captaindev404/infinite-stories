## MODIFIED Requirements

### Requirement: Repositories Must Use Backend API Only

All repository operations SHALL use the backend API exclusively, with no direct OpenAI API calls. Illustration placeholder views SHALL NOT display "coming soon" language.

#### Scenario: HeroRepository creates hero via backend

**Given** a user wants to create a new hero
**When** `HeroRepository.createHero()` is called
**Then** it POSTs to `/api/heroes` with hero data
**And** no direct OpenAI API calls are made
**And** the avatar generation is requested via `POST /api/heroes/[id]/avatar`
**And** the backend handles all OpenAI interactions

#### Scenario: Illustration placeholder shows loading state
- **WHEN** an illustration is not yet generated
- **THEN** the placeholder view displays a loading/generating indicator (e.g., spinner with "Generating illustration...")
- **AND** the text "Coming Soon" does NOT appear
