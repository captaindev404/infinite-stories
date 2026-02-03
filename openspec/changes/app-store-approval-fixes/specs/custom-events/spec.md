## MODIFIED Requirements

### Requirement: Custom Events CRUD API

The backend SHALL provide RESTful endpoints for managing custom story events with user ownership. The PictogramGenerationView SHALL NOT be accessible to users until pictogram generation is implemented.

#### Scenario: User lists their custom events

**Given** an authenticated user with custom events in the database
**When** the user GETs `/api/v1/custom-events`
**Then** the API returns all events owned by that user
**And** the response includes pagination metadata
**And** events are ordered by `createdAt` descending

#### Scenario: Pictogram generation view is hidden
- **WHEN** user navigates the custom event creation flow
- **THEN** the PictogramGenerationView is not reachable
- **AND** no "coming soon" text is displayed anywhere in the flow
