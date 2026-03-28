## ADDED Requirements

### Requirement: Apple Sign-In Provider Must Be Configured

The backend SHALL support Sign in with Apple as an authentication provider via Better Auth's social providers configuration.

#### Scenario: Apple provider is configured with valid credentials

- **GIVEN** the backend has Apple provider environment variables set (APPLE_CLIENT_ID, APPLE_CLIENT_SECRET, APPLE_APP_BUNDLE_IDENTIFIER)
- **WHEN** Better Auth initializes
- **THEN** the Apple social provider is available for authentication
- **AND** the provider uses the App Bundle ID for native iOS token validation
- **AND** `appleid.apple.com` is added to trusted origins

#### Scenario: Apple provider handles missing credentials gracefully

- **GIVEN** Apple provider environment variables are not set
- **WHEN** the backend starts
- **THEN** the Apple provider is not enabled
- **AND** email/password authentication continues to work
- **AND** a warning is logged about missing Apple credentials

### Requirement: Backend Must Accept Apple ID Token Authentication

The backend SHALL accept Apple ID tokens from native iOS clients and create/validate sessions.

#### Scenario: Valid Apple ID token creates new user

- **GIVEN** a valid Apple ID token with email "user@icloud.com"
- **AND** no existing user with that email
- **WHEN** the iOS app POSTs to `/api/auth/sign-in/social` with provider "apple" and the ID token
- **THEN** a new user is created with the Apple email
- **AND** an account is created linking the Apple provider
- **AND** a session token is returned
- **AND** the response includes `{ user: {...}, session: {...} }` with status 200

#### Scenario: Valid Apple ID token links to existing account

- **GIVEN** a valid Apple ID token with email "existing@example.com"
- **AND** an existing user with that email (signed up via email/password)
- **WHEN** the iOS app POSTs to `/api/auth/sign-in/social` with provider "apple" and the ID token
- **THEN** the Apple provider is linked to the existing account
- **AND** a session token is returned for the existing user
- **AND** the user can now sign in with either method

#### Scenario: Invalid Apple ID token is rejected

- **GIVEN** an invalid or expired Apple ID token
- **WHEN** the iOS app POSTs to `/api/auth/sign-in/social` with provider "apple"
- **THEN** the API returns 401 Unauthorized
- **AND** the error message indicates token validation failed
- **AND** no session is created

#### Scenario: Apple ID token with hidden email is accepted

- **GIVEN** a valid Apple ID token where user chose to hide their email
- **AND** Apple provides a private relay email (e.g., "xyz123@privaterelay.appleid.com")
- **WHEN** the iOS app authenticates with the ID token
- **THEN** the user is created/authenticated with the private relay email
- **AND** the user can use the app normally

## MODIFIED Requirements

### Requirement: Auth Endpoints Must Be Functional

The backend SHALL provide fully functional authentication endpoints for user registration, login, session management, logout, and social provider authentication.

#### Scenario: User signs up successfully

**Given** a new user with email "test@example.com" and password "SecurePass123"
**When** the user POSTs to `/api/auth/sign-up` with valid credentials
**Then** a new user is created in the database
**And** a session token is generated and returned
**And** the response includes `{ user: {...}, session: {...} }` with status 201

#### Scenario: User signs in with valid credentials

**Given** an existing user in the database
**When** the user POSTs to `/api/auth/sign-in` with correct email and password
**Then** a session token is generated and returned
**And** the response includes `{ user: {...}, session: {...} }` with status 200
**And** the token is valid for 30 days

#### Scenario: User signs in with invalid credentials

**Given** a user attempts to sign in
**When** the password is incorrect
**Then** the API returns 401 Unauthorized
**And** the error message is "Invalid credentials"
**And** no session token is generated

#### Scenario: User session is validated

**Given** an authenticated user with a valid session token
**When** the user makes a request to a protected endpoint with `Authorization: Bearer <token>`
**Then** the middleware validates the token
**And** the request is allowed to proceed
**And** the user context is available in the route handler

#### Scenario: User signs in with Apple

**Given** a user with a valid Apple ID token
**When** the user authenticates via the Apple social provider endpoint
**Then** a session token is generated and returned
**And** the response includes `{ user: {...}, session: {...} }` with status 200
**And** the account is linked to the Apple provider
