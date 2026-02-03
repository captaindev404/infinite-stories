## ADDED Requirements

### Requirement: Backend Account Deletion Endpoint
The backend SHALL provide a `DELETE /api/v1/user/account` endpoint that permanently deletes all user data from the server.

#### Scenario: Authenticated user deletes account
- **WHEN** authenticated user sends `DELETE /api/v1/user/account`
- **THEN** all user data is permanently deleted (heroes, stories, custom events, analytics, audio files, illustrations)
- **AND** response is 204 No Content
- **AND** the user's session token is invalidated

#### Scenario: Unauthenticated request is rejected
- **WHEN** unauthenticated request sends `DELETE /api/v1/user/account`
- **THEN** response is 401 Unauthorized

### Requirement: In-App Account Deletion UI
The SettingsView SHALL include a "Delete Account" button that triggers full account deletion (server + local).

#### Scenario: User taps Delete Account
- **WHEN** user taps "Delete Account" in Settings
- **THEN** a confirmation dialog appears explaining that all data will be permanently deleted
- **AND** the dialog requires explicit confirmation (e.g., "Delete My Account" button in red)

#### Scenario: User confirms account deletion
- **WHEN** user confirms account deletion
- **THEN** the app calls `DELETE /api/v1/user/account`
- **AND** on success, all local data is erased (same as existing eraseAllData)
- **AND** the user is signed out and returned to the authentication screen

#### Scenario: Account deletion fails due to network error
- **WHEN** account deletion API call fails
- **THEN** the app shows an error with retry option
- **AND** no local data is erased until the server confirms deletion

### Requirement: Delete Account Endpoint in Endpoint Enum
The iOS `Endpoint` enum SHALL include a `deleteAccount` case mapped to `DELETE /api/v1/user/account`.

#### Scenario: Endpoint is defined
- **WHEN** inspecting `Endpoint.swift`
- **THEN** `case deleteAccount` exists with method `DELETE` and path `/api/v1/user/account`
