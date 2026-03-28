## ADDED Requirements

### Requirement: Pagination Must Be Capped Server-Side
All list endpoints SHALL cap the `limit` parameter at 100 and ensure `offset` is non-negative. Invalid values SHALL fall back to safe defaults.

#### Scenario: Limit exceeding cap is clamped
- **WHEN** an authenticated user requests `/api/v1/heroes?limit=500`
- **THEN** the response returns at most 100 items
- **AND** the pagination metadata reflects `limit: 100`

#### Scenario: Negative offset defaults to zero
- **WHEN** an authenticated user requests `/api/v1/heroes?offset=-10`
- **THEN** the offset is treated as 0
- **AND** results start from the beginning

#### Scenario: Non-numeric limit defaults to 50
- **WHEN** an authenticated user requests `/api/v1/heroes?limit=abc`
- **THEN** the limit defaults to 50
- **AND** the response succeeds normally

### Requirement: Scene Extraction Must Sandbox User Content
The scene extraction endpoint SHALL wrap user-supplied `storyContent` and `eventContext` in XML delimiters with an untrusted-content system instruction.

#### Scenario: Story content is sandboxed in prompt
- **WHEN** an authenticated user POSTs to `/api/v1/stories/extract-scenes` with `storyContent`
- **THEN** the content is wrapped in `<user_input>` tags before embedding in the AI prompt
- **AND** the system prompt includes the untrusted-content instruction

#### Scenario: Event context is sandboxed in prompt
- **WHEN** the request includes `eventContext`
- **THEN** the event context is also wrapped in `<user_input>` tags

### Requirement: HTTP Security Headers Must Be Present
All responses SHALL include standard security headers to prevent common web attacks.

#### Scenario: HSTS header is present
- **WHEN** any request is made to the backend
- **THEN** the response includes `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`

#### Scenario: Clickjacking protection is present
- **WHEN** any request is made to the backend
- **THEN** the response includes `X-Frame-Options: SAMEORIGIN`

#### Scenario: MIME sniffing protection is present
- **WHEN** any request is made to the backend
- **THEN** the response includes `X-Content-Type-Options: nosniff`

#### Scenario: Content Security Policy is present
- **WHEN** any request is made to the backend
- **THEN** the response includes a `Content-Security-Policy` header
- **AND** the policy restricts default-src to 'self'

### Requirement: Analytics Sessions Must Verify Story Ownership
The analytics sessions endpoint SHALL verify that the requesting user owns the story when filtering by `storyId`.

#### Scenario: User queries own story sessions
- **WHEN** an authenticated user requests sessions for a story they own
- **THEN** the sessions are returned normally

#### Scenario: User queries another user's story sessions
- **WHEN** an authenticated user requests sessions for a story they do NOT own
- **THEN** the response is `403 Forbidden`
- **AND** no session data is returned

### Requirement: Audio Generation Errors Must Be Sanitized Before Storage
Error messages stored in `audioGenerationError` SHALL NOT contain internal details such as model names, token counts, or raw API error bodies.

#### Scenario: OpenAI error is sanitized before storage
- **WHEN** an audio generation call fails with an OpenAI error
- **THEN** the stored `audioGenerationError` contains a generic message (e.g., "Audio generation failed")
- **AND** the raw error is logged server-side only

#### Scenario: Stored error does not leak model details
- **WHEN** a previously failed audio generation error is returned to the client
- **THEN** the response does NOT contain model names, token counts, or internal URLs

### Requirement: Production Error Responses Must Not Leak Internal Details
In production, generic 500 error responses SHALL NOT include internal error messages or stack traces.

#### Scenario: 500 error in production returns generic message
- **WHEN** an unexpected error occurs in production (`NODE_ENV=production`)
- **THEN** the response body contains `{ "error": "InternalServerError", "message": "An unexpected error occurred" }`
- **AND** the actual error message is logged server-side

#### Scenario: 500 error in development returns detailed message
- **WHEN** an unexpected error occurs in development
- **THEN** the response body contains the actual error message for debugging

#### Scenario: 4xx errors always return descriptive messages
- **WHEN** a validation or auth error occurs in any environment
- **THEN** the response contains the specific error description (e.g., "heroId is required")

### Requirement: Batch Import Must Validate Audio URLs
The batch story import endpoint SHALL validate that `audioUrl` values match the expected R2 storage URL pattern.

#### Scenario: Valid R2 URL is accepted
- **WHEN** a batch import includes `audioUrl` matching the configured R2 public URL
- **THEN** the story is imported with the audio URL

#### Scenario: External URL is rejected
- **WHEN** a batch import includes `audioUrl` pointing to an external domain (not R2)
- **THEN** the import rejects that story with a validation error
- **AND** other stories in the batch are not affected

### Requirement: Docker Compose Must Not Use Hardcoded Credentials
The development Docker Compose configuration SHALL use environment variable substitution for database credentials instead of hardcoded values.

#### Scenario: Docker compose uses env var for password
- **WHEN** Docker Compose starts the PostgreSQL service
- **THEN** the password is read from `POSTGRES_PASSWORD` environment variable
- **AND** a `.env.docker.example` file documents the required variables

#### Scenario: PostgreSQL is not exposed on host port
- **WHEN** Docker Compose starts the PostgreSQL service
- **THEN** port 5432 is NOT bound to the host
- **AND** the database is only accessible via Docker internal network

### Requirement: Email Verification Strategy Must Be Documented
The backend SHALL document the email verification decision and provide clear migration steps for future enablement.

#### Scenario: Auth config documents verification status
- **WHEN** a developer reads the auth configuration
- **THEN** a comment explains that email verification is deferred because Apple Sign-In verifies emails
- **AND** migration steps are documented for enabling verification with an email service
