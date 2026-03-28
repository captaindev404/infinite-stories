## ADDED Requirements

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
