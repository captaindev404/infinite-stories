# custom-events Specification

## Purpose
TBD - created by archiving change migrate-custom-events-api. Update Purpose after archive.
## Requirements
### Requirement: Custom Events CRUD API

The backend SHALL provide RESTful endpoints for managing custom story events with user ownership. The PictogramGenerationView SHALL NOT be accessible to users until pictogram generation is implemented.

#### Scenario: User lists their custom events

**Given** an authenticated user with custom events in the database
**When** the user GETs `/api/v1/custom-events`
**Then** the API returns all events owned by that user
**And** the response includes pagination metadata
**And** events are ordered by `createdAt` descending

#### Scenario: User lists custom events with pagination

**Given** an authenticated user with 25 custom events
**When** the user GETs `/api/v1/custom-events?limit=10&offset=10`
**Then** the API returns events 11-20
**And** the response includes `hasMore: true`

#### Scenario: User creates a custom event

**Given** an authenticated user
**When** the user POSTs to `/api/v1/custom-events` with valid event data
**Then** a new event is created in the database with `userId` set to the authenticated user
**And** the response includes the created event with status 201
**And** the event has `usageCount: 0` and `isFavorite: false`

#### Scenario: User creates event with invalid data

**Given** an authenticated user
**When** the user POSTs to `/api/v1/custom-events` without required fields (title, promptSeed)
**Then** the API returns 400 Bad Request
**And** the error message lists missing required fields

#### Scenario: User retrieves a single custom event

**Given** an authenticated user who owns event with id "abc123"
**When** the user GETs `/api/v1/custom-events/abc123`
**Then** the API returns the event details with status 200

#### Scenario: User retrieves event they don't own

**Given** an authenticated user
**And** an event with id "xyz789" owned by a different user
**When** the user GETs `/api/v1/custom-events/xyz789`
**Then** the API returns 404 Not Found
**And** no event data is leaked

#### Scenario: User updates a custom event

**Given** an authenticated user who owns event with id "abc123"
**When** the user PATCHes `/api/v1/custom-events/abc123` with `{ "title": "New Title" }`
**Then** the event title is updated
**And** the `updatedAt` timestamp is refreshed
**And** the response includes the updated event

#### Scenario: User marks event as favorite

**Given** an authenticated user who owns event with id "abc123"
**When** the user PATCHes `/api/v1/custom-events/abc123` with `{ "isFavorite": true }`
**Then** the event `isFavorite` is set to true
**And** the response includes the updated event

#### Scenario: User deletes a custom event

**Given** an authenticated user who owns event with id "abc123"
**When** the user DELETEs `/api/v1/custom-events/abc123`
**Then** the event is removed from the database
**And** the response is 204 No Content

#### Scenario: User deletes event they don't own

**Given** an authenticated user
**And** an event with id "xyz789" owned by a different user
**When** the user DELETEs `/api/v1/custom-events/xyz789`
**Then** the API returns 404 Not Found
**And** the event is not deleted

### Requirement: Custom Event AI Enhancement

The backend SHALL provide an endpoint to enhance custom event prompts using AI.

#### Scenario: User enhances a custom event

**Given** an authenticated user who owns event with id "abc123"
**And** the event has `aiEnhanced: false`
**When** the user POSTs to `/api/v1/custom-events/abc123/enhance`
**Then** the backend calls GPT-4o-mini to enhance the prompt seed
**And** relevant keywords are generated
**And** the event `aiEnhanced` is set to true
**And** the `aiEnhancementMetadata` stores enhancement details
**And** the response includes the enhanced event

#### Scenario: User enhances already-enhanced event

**Given** an authenticated user who owns event with id "abc123"
**And** the event has `aiEnhanced: true`
**When** the user POSTs to `/api/v1/custom-events/abc123/enhance`
**Then** the backend re-enhances the prompt
**And** the `aiEnhancementMetadata` is updated
**And** the response includes the re-enhanced event

#### Scenario: AI enhancement fails

**Given** an authenticated user who owns event with id "abc123"
**When** the user POSTs to `/api/v1/custom-events/abc123/enhance`
**And** the OpenAI API call fails
**Then** the API returns 500 Internal Server Error
**And** the original event data is not modified
**And** the error is logged for debugging

### Requirement: Usage Tracking

The backend SHALL track custom event usage when stories are created.

#### Scenario: Story created with custom event increments usage

**Given** an authenticated user creates a story with `customEventId: "abc123"`
**When** the story is successfully created
**Then** the custom event's `usageCount` is incremented by 1
**And** the `lastUsedAt` is updated to the current timestamp

### Requirement: iOS API Integration

The iOS app SHALL use the backend API for all custom event operations.

#### Scenario: iOS app fetches custom events on view appear

**Given** the user opens the custom events management view
**When** the view appears
**Then** the repository calls `GET /api/v1/custom-events`
**And** a loading indicator is shown during the request
**And** the events are displayed when loaded

#### Scenario: iOS app handles network error

**Given** the user opens the custom events management view
**When** the API request fails due to network error
**Then** an error view is displayed
**And** the error view includes a retry button
**And** tapping retry re-attempts the request

#### Scenario: iOS app creates custom event

**Given** the user fills out the custom event creation form
**When** the user taps save
**Then** the repository calls `POST /api/v1/custom-events`
**And** a loading indicator is shown
**And** on success, the user is navigated back to the events list
**And** the new event appears in the list

#### Scenario: iOS app blocks operations when offline

**Given** the device has no network connection
**When** the user attempts to create, edit, or delete a custom event
**Then** the operation is blocked
**And** an offline message is displayed

#### Scenario: Pictogram generation view is hidden
- **WHEN** user navigates the custom event creation flow
- **THEN** the PictogramGenerationView is not reachable
- **AND** no "coming soon" text is displayed anywhere in the flow

