## ADDED Requirements

### Requirement: CORS Origin Allowlist
The middleware SHALL replace the wildcard `Access-Control-Allow-Origin: *` with an explicit origin allowlist. Requests with no `Origin` header (native iOS app) SHALL be allowed through without CORS restrictions.

#### Scenario: Request from allowed origin
- **WHEN** a request arrives with `Origin: https://infinite-stories-web.captaindev.io`
- **THEN** the response includes `Access-Control-Allow-Origin: https://infinite-stories-web.captaindev.io`
- **AND** the response includes `Vary: Origin`

#### Scenario: Request from disallowed origin
- **WHEN** a request arrives with `Origin: https://evil-site.com`
- **THEN** the response does NOT include `Access-Control-Allow-Origin`
- **AND** the browser blocks the cross-origin request

#### Scenario: Request with no Origin header (native iOS app)
- **WHEN** a request arrives with no `Origin` header and a valid `Authorization: Bearer` token
- **THEN** the request is allowed through without CORS restrictions
- **AND** no `Access-Control-Allow-Origin` header is set

#### Scenario: Allowlist covers all environments
- **WHEN** the middleware initializes
- **THEN** the allowlist includes: `http://localhost:3000`, `capacitor://localhost`, `ionic://localhost`, `https://appleid.apple.com`, the value of `BETTER_AUTH_URL`, and the value of `NEXT_PUBLIC_APP_URL`

### Requirement: AI Endpoints Must Require Authentication
All API endpoints that call OpenAI services SHALL require a valid authenticated session before processing the request.

#### Scenario: Authenticated request to story generation
- **WHEN** an authenticated user POSTs to `/api/v1/stories/generate` with a valid Bearer token
- **THEN** the request is processed normally
- **AND** the user's identity is available for rate limiting

#### Scenario: Unauthenticated request to story generation
- **WHEN** an unauthenticated request POSTs to `/api/v1/stories/generate`
- **THEN** the response is `401 Unauthorized` with body `{ "code": "Unauthorized", "message": "Authentication required" }`
- **AND** no OpenAI API call is made

#### Scenario: Unauthenticated request to audio generation
- **WHEN** an unauthenticated request POSTs to `/api/v1/audio/generate`
- **THEN** the response is `401 Unauthorized`
- **AND** no OpenAI TTS call is made

#### Scenario: Unauthenticated request to image generation
- **WHEN** an unauthenticated request POSTs to `/api/v1/images/generate-avatar`
- **THEN** the response is `401 Unauthorized`
- **AND** no OpenAI image generation call is made

#### Scenario: Unauthenticated request to AI assistant
- **WHEN** an unauthenticated request POSTs to `/api/v1/ai-assistant/enhance-prompt`
- **THEN** the response is `401 Unauthorized`
- **AND** no OpenAI API call is made

### Requirement: Request Body Validation with Zod
All AI endpoints SHALL validate request bodies using Zod schemas before processing. Invalid requests SHALL be rejected with a descriptive 400 error.

#### Scenario: Valid story generation request
- **WHEN** an authenticated user POSTs to `/api/v1/stories/generate` with `{ "heroId": "abc123", "eventType": "birthday", "language": "en" }`
- **THEN** the request passes validation and is processed

#### Scenario: Story generation with missing required field
- **WHEN** an authenticated user POSTs to `/api/v1/stories/generate` with `{ "language": "en" }` (missing heroId)
- **THEN** the response is `400 Bad Request` with body `{ "code": "VALIDATION_ERROR", "message": "heroId is required" }`

#### Scenario: Audio generation text exceeds max length
- **WHEN** an authenticated user POSTs to `/api/v1/audio/generate` with `text` exceeding 10,000 characters
- **THEN** the response is `400 Bad Request` with body indicating text is too long
- **AND** no OpenAI TTS call is made

#### Scenario: Invalid language enum value
- **WHEN** an authenticated user POSTs with `"language": "klingon"`
- **THEN** the response is `400 Bad Request` with body indicating invalid language value

#### Scenario: Avatar prompt exceeds max length
- **WHEN** an authenticated user POSTs to `/api/v1/images/generate-avatar` with `prompt` exceeding 500 characters
- **THEN** the response is `400 Bad Request`

### Requirement: Centralized Auth and Validation Wrapper
A reusable `withAuthAndValidation` utility SHALL provide authentication, Zod validation, and rate limiting in a single wrapper for route handlers.

#### Scenario: Wrapper enforces auth, validation, and rate limit in order
- **WHEN** a request is processed through `withAuthAndValidation`
- **THEN** authentication is checked first
- **AND** rate limiting is checked second
- **AND** Zod validation is checked third
- **AND** the handler is called only if all three pass

#### Scenario: Wrapper returns consistent error format
- **WHEN** authentication fails
- **THEN** the response uses the standard `{ "code": "...", "message": "..." }` format
- **AND** the HTTP status code matches the error type (401, 429, 400)

### Requirement: Debug Endpoint Must Not Exist in Production
The `/api/test-auth` endpoint SHALL be deleted. No endpoint SHALL log raw session tokens or Authorization headers.

#### Scenario: test-auth endpoint is removed
- **WHEN** a request is made to `/api/test-auth`
- **THEN** the response is `404 Not Found`

#### Scenario: No endpoint logs session tokens
- **WHEN** any API endpoint processes a request
- **THEN** the raw Bearer token value is NOT written to stdout, stderr, or any log output

### Requirement: Health Endpoint Must Not Leak Configuration
The public health endpoint SHALL return only a boolean health status. Environment variable names and values SHALL NOT appear in any public response.

#### Scenario: Healthy system returns minimal response
- **WHEN** all required services are configured
- **THEN** `GET /api/v1/health` returns `{ "status": "healthy" }` with HTTP 200

#### Scenario: Unhealthy system returns generic error
- **WHEN** a required environment variable is missing
- **THEN** `GET /api/v1/health` returns `{ "status": "unhealthy" }` with HTTP 503
- **AND** the response does NOT name which variable is missing
- **AND** the missing variable name is logged server-side only
