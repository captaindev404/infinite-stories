# Spec: Backend Authentication

## Purpose

Define the authentication and session management system for the InfiniteStories backend API using Better Auth, including user registration, login, session validation, and token refresh.
## Requirements
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

### Requirement: Middleware Must Protect API Routes

All API routes except public ones SHALL require valid authentication via middleware.

#### Scenario: Protected endpoint requires auth

**Given** a user without a session token
**When** the user makes a GET request to `/api/heroes`
**Then** the middleware returns 401 Unauthorized
**And** the error message is "Authentication required"
**And** the request does not reach the route handler

#### Scenario: Protected endpoint accepts valid token

**Given** a user with a valid session token
**When** the user makes a GET request to `/api/heroes` with `Authorization: Bearer <token>`
**Then** the middleware validates the token
**And** the request proceeds to the route handler
**And** the user context contains the authenticated user ID

#### Scenario: Public endpoint allows unauthenticated access

**Given** any user (authenticated or not)
**When** the user makes a GET request to `/api/health`
**Then** the request is allowed without authentication
**And** the response is returned successfully

#### Scenario: Expired token is rejected

**Given** a user with an expired session token
**When** the user makes a request to `/api/heroes` with the expired token
**Then** the middleware returns 401 Unauthorized
**And** the error message is "Invalid or expired session"

### Requirement: Session Management Must Be Secure

Session tokens SHALL be securely generated, stored, and validated with proper expiration.

#### Scenario: Session token has appropriate expiration

**Given** a user signs in successfully
**When** the session token is generated
**Then** the token expires in 30 days
**And** the token includes a refresh policy to update every 24 hours
**And** the token is stored in the database with expiration timestamp

#### Scenario: Session token is invalidated on sign-out

**Given** a user is signed in with an active session
**When** the user POSTs to `/api/auth/sign-out`
**Then** the session is deleted from the database
**And** the token is no longer valid
**And** subsequent requests with that token return 401 Unauthorized

### Requirement: Rate Limits Must Be Configurable via Environment Variables
The backend rate limiter SHALL read per-operation limits from environment variables with safe defaults. Invalid or missing env var values SHALL fall back to defaults silently.

#### Scenario: Rate limits use environment variable values
- **WHEN** the backend starts with `RATE_LIMIT_STORY_GENERATION=10` set
- **THEN** story generation is limited to 10 requests per hour per user
- **AND** the configured value overrides the default

#### Scenario: Rate limits fall back to defaults when env vars are missing
- **WHEN** the backend starts without rate limit env vars set
- **THEN** the following defaults are used: story_generation=5/hr, audio_generation=10/hr, avatar_generation=3/hr, illustration_generation=20/hr, ai_assistant=30/hr

#### Scenario: Invalid rate limit env var is ignored
- **WHEN** the backend starts with `RATE_LIMIT_STORY_GENERATION=-1` or `RATE_LIMIT_STORY_GENERATION=abc`
- **THEN** the default value (5) is used instead
- **AND** no error is thrown at startup

### Requirement: Auth Errors Must Return Consistent 401 Status
Authentication failures SHALL always return HTTP 401 with a consistent error format, never 500.

#### Scenario: Auth failure returns 401
- **WHEN** an unauthenticated request is made to a protected endpoint
- **THEN** the response is `401 Unauthorized` with body `{ "code": "Unauthorized", "message": "Authentication required" }`
- **AND** the response is never 500 Internal Server Error

#### Scenario: Expired token returns 401
- **WHEN** a request is made with an expired Bearer token
- **THEN** the response is `401 Unauthorized`
- **AND** the response is never 500 Internal Server Error

### Requirement: Mass Assignment Fields Must Be Restricted
Endpoints that accept user input SHALL only allow client-settable fields. Server-managed fields (usage counts, timestamps, generated URLs) SHALL be rejected if provided by the client.

#### Scenario: Custom event PATCH rejects usageCount
- **WHEN** an authenticated user PATCHes `/api/v1/custom-events/:id` with `{ "usageCount": 999 }`
- **THEN** the `usageCount` field is ignored or rejected
- **AND** the stored `usageCount` value is unchanged

#### Scenario: Custom event PATCH rejects lastUsedAt
- **WHEN** an authenticated user PATCHes `/api/v1/custom-events/:id` with `{ "lastUsedAt": "2026-01-01" }`
- **THEN** the `lastUsedAt` field is ignored or rejected
- **AND** the stored `lastUsedAt` value is unchanged

#### Scenario: Hero creation rejects avatarUrl
- **WHEN** an authenticated user POSTs to `/api/v1/heroes` with `{ "name": "Test", "avatarUrl": "https://evil.com/img.png" }`
- **THEN** the `avatarUrl` field is ignored
- **AND** the hero is created without an avatar URL

#### Scenario: Hero creation rejects avatarPrompt and avatarGenerationId
- **WHEN** an authenticated user POSTs to `/api/v1/heroes` with `avatarPrompt` or `avatarGenerationId` in the body
- **THEN** these fields are ignored
- **AND** the hero is created without avatar generation data

### Requirement: OpenAI Error Responses Must Be Sanitized
All endpoints that call OpenAI services SHALL return sanitized error messages to clients. Full error details SHALL be logged server-side only.

#### Scenario: OpenAI API error returns generic message
- **WHEN** an OpenAI API call fails with an internal error
- **THEN** the client receives `{ "code": "AI_ERROR", "message": "An error occurred while generating content. Please try again." }` with HTTP 502
- **AND** the full OpenAI error is logged server-side

#### Scenario: OpenAI rate limit returns specific code
- **WHEN** an OpenAI API call fails with HTTP 429 (rate limit)
- **THEN** the client receives `{ "code": "RATE_LIMIT", "message": "AI service is temporarily busy. Please try again in a moment." }` with HTTP 429
- **AND** the full error is logged server-side

#### Scenario: OpenAI error never leaks internal details
- **WHEN** any OpenAI API call fails
- **THEN** the client response does NOT contain the OpenAI API key, internal URLs, model names, or raw error messages
- **AND** only the sanitized code and message are returned

### Requirement: User Input Must Be Sandboxed in AI Prompts
All user-supplied content embedded in OpenAI prompts SHALL be wrapped in XML delimiters with an untrusted-content instruction.

#### Scenario: User input is wrapped in XML delimiters
- **WHEN** a user's text is embedded in an AI prompt (story generation, audio, enhancement, etc.)
- **THEN** the text is wrapped as `<user_input>...</user_input>`
- **AND** the system prompt includes an instruction that content between these tags is untrusted

#### Scenario: User input containing XML tags is sanitized
- **WHEN** a user's text contains `<user_input>` or `</user_input>` strings
- **THEN** these tags are stripped before wrapping
- **AND** the prompt injection attempt is neutralized

#### Scenario: AI assistant enhance-prompt sandboxes all fields
- **WHEN** the enhance-prompt endpoint receives title, description, category, ageRange, and tone
- **THEN** each field is individually wrapped in `<user_input>` tags before embedding in the prompt
- **AND** the system prompt marks these as untrusted data

