# reading-journey Specification

## Purpose
TBD - created by archiving change migrate-reading-journey-api. Update Purpose after archive.
## Requirements
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

#### Scenario: Summary returns zeros for new user
- **WHEN** iOS app requests `GET /api/v1/analytics/summary`
- **AND** user has no stories or listening history
- **THEN** response contains all fields with zero values
- **AND** `lastActivityDate` is null

### Requirement: Listening Activity Endpoint

The backend SHALL provide a time-series endpoint for listening activity data.

#### Scenario: Fetch weekly listening activity
- **WHEN** iOS app requests `GET /api/v1/analytics/activity?range=week`
- **AND** user is authenticated
- **THEN** response contains:
  - `range`: "week"
  - `dataPoints`: array of 7 entries, one per day
  - Each entry has `date` (ISO8601) and `minutes` (listening time)
- **AND** data is sorted chronologically (oldest first)

#### Scenario: Fetch monthly listening activity
- **WHEN** iOS app requests `GET /api/v1/analytics/activity?range=month`
- **THEN** response contains 30 daily data points

#### Scenario: Fetch yearly listening activity
- **WHEN** iOS app requests `GET /api/v1/analytics/activity?range=year`
- **THEN** response contains 365 daily data points

### Requirement: Hero Performance Endpoint

The backend SHALL provide per-hero analytics for story distribution and activity.

#### Scenario: Fetch hero performance data
- **WHEN** iOS app requests `GET /api/v1/analytics/heroes`
- **AND** user is authenticated
- **THEN** response contains array of hero stats:
  - `heroId`: backend hero ID
  - `heroName`: hero display name
  - `storyCount`: number of stories for this hero
  - `totalListeningTime`: seconds for this hero's stories
  - `lastStoryDate`: ISO8601 of most recent story
- **AND** heroes are sorted by `storyCount` descending

#### Scenario: Most active hero is indicated
- **WHEN** response contains hero performance data
- **THEN** first hero in array is the most active (highest story count)
- **AND** each hero includes `isMostActive` boolean field

### Requirement: Milestones Endpoint

The backend SHALL track and return user achievement milestones.

#### Scenario: Fetch milestone status
- **WHEN** iOS app requests `GET /api/v1/analytics/milestones`
- **AND** user is authenticated
- **THEN** response contains array of milestones:
  - `id`: milestone identifier
  - `title`: display title
  - `icon`: SF Symbol name
  - `type`: "stories" | "listeningTime" | "streak"
  - `threshold`: value required to unlock
  - `currentValue`: user's current progress
  - `isUnlocked`: boolean
  - `unlockedAt`: ISO8601 if unlocked, null otherwise

#### Scenario: Milestones include all achievement types
- **WHEN** milestones are fetched
- **THEN** response includes story milestones (1, 5, 10, 25, 50)
- **AND** listening time milestones (1h, 5h)
- **AND** streak milestones (7 days, 30 days)

### Requirement: Listening Session Tracking

The iOS app SHALL report listening sessions to enable accurate time tracking.

#### Scenario: Report listening session on playback end
- **WHEN** user completes or exits audio playback
- **THEN** app sends `POST /api/v1/analytics/sessions` with:
  - `storyId`: backend story ID
  - `startedAt`: ISO8601 when playback started
  - `endedAt`: ISO8601 when playback ended
  - `completed`: boolean if story finished
  - `duration`: actual seconds listened
- **AND** backend updates aggregated listening time

#### Scenario: Session validates duration
- **WHEN** session is posted
- **AND** duration exceeds story's estimated duration by >50%
- **THEN** backend caps duration at 1.5x estimated duration
- **AND** logs anomaly for review

### Requirement: Reading Insights Endpoint

The backend SHALL provide derived insights from listening patterns.

#### Scenario: Fetch reading insights
- **WHEN** iOS app requests `GET /api/v1/analytics/insights`
- **AND** user has listening history
- **THEN** response contains:
  - `averageStoryLength`: average story duration in seconds
  - `averageListensPerStory`: mean play count
  - `preferredListeningHour`: most common hour (0-23)
  - `mostListenedStory`: { id, title, playCount } or null

#### Scenario: Insights handle insufficient data
- **WHEN** user has fewer than 3 stories
- **THEN** `preferredListeningHour` is null
- **AND** `averageListensPerStory` uses available data

### Requirement: ReadingJourneyRepository Pattern

The iOS app SHALL use a repository to access all analytics data from the backend API.

#### Scenario: Repository fetches summary
- **WHEN** `ReadingJourneyRepository.fetchSummary()` is called
- **THEN** it requests `GET /api/v1/analytics/summary`
- **AND** returns `AnalyticsSummary` model
- **AND** throws `APIError.networkUnavailable` if offline

#### Scenario: Repository handles network errors
- **WHEN** any analytics fetch fails due to network
- **THEN** repository throws appropriate `APIError`
- **AND** view displays `ErrorView` with retry option

#### Scenario: Repository caches responses
- **WHEN** analytics data is fetched successfully
- **THEN** repository caches response for 5 minutes
- **AND** subsequent calls within TTL return cached data
- **AND** user can force refresh

### Requirement: Reading Journey Views Use Repository

Views SHALL NOT use SwiftData `@Query` for statistics; they MUST use `ReadingJourneyRepository`.

#### Scenario: ReadingJourneyView fetches from repository
- **WHEN** `ReadingJourneyView` appears
- **THEN** it calls `ReadingJourneyRepository` methods
- **AND** displays loading indicator during fetch
- **AND** shows data when loaded
- **AND** shows `ErrorView` on failure

#### Scenario: Statistics refresh on pull
- **WHEN** user pulls to refresh on Reading Journey
- **THEN** repository fetches fresh data (bypassing cache)
- **AND** UI updates with new values

