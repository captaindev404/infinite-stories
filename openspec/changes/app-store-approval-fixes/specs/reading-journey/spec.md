## MODIFIED Requirements

### Requirement: Analytics Summary Endpoint

The backend SHALL provide a summary endpoint that returns aggregated reading statistics for the authenticated user. The iOS app SHALL NOT display a favorite stories section until the backend endpoint is available.

#### Scenario: Fetch analytics summary successfully
- **WHEN** iOS app requests `GET /api/v1/analytics/summary`
- **AND** user is authenticated
- **THEN** response contains:
  - `totalStories`: number of stories created for user
  - `totalListeningTime`: accumulated seconds of actual listening
  - `totalPlayCount`: total story playback count
  - `currentStreak`: consecutive days with listening activity
  - `longestStreak`: historical best streak
  - `favoriteCount`: number of favorited stories
  - `lastActivityDate`: ISO8601 timestamp of last session
- **AND** HTTP status is 200

#### Scenario: Favorite stories section is hidden until backend ready
- **WHEN** the ReadingJourneyView is displayed
- **THEN** the favorite stories section is NOT shown
- **AND** no TODO placeholder or empty section is visible to the user
