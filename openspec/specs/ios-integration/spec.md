# Spec: iOS Backend Integration

## Purpose

Define how the iOS app integrates with the backend API for all operations, replacing direct OpenAI API calls with backend-proxied requests including authentication, authorized API calls, and response handling.
## Requirements
### Requirement: APIClient Must Inject Auth Headers

The APIClient SHALL automatically inject authentication headers for all API requests when the user is signed in.

#### Scenario: Authenticated request includes Bearer token

**Given** a user is signed in with session token "abc123xyz"
**When** the app makes any API request via APIClient
**Then** the request includes header `Authorization: Bearer abc123xyz`
**And** the token is retrieved from AuthStateManager.shared.sessionToken
**And** the request proceeds to the backend

#### Scenario: Unauthenticated request omits auth header

**Given** no user is signed in
**When** the app makes a request to a public endpoint `/api/health`
**Then** no `Authorization` header is included
**And** the request proceeds normally

#### Scenario: APIClient handles 401 Unauthorized

**Given** a user is signed in with an expired token
**When** the app makes an API request
**And** the backend returns 401 Unauthorized
**Then** APIClient calls `AuthStateManager.shared.signOut()`
**And** the app navigates to AuthenticationView
**And** a user-friendly alert is shown: "Session expired, please sign in again"

### Requirement: Repositories Must Use Backend API Only

All repository operations SHALL use the backend API exclusively, with no direct OpenAI API calls. Illustration placeholder views SHALL NOT display "coming soon" language.

#### Scenario: HeroRepository creates hero via backend

**Given** a user wants to create a new hero
**When** `HeroRepository.createHero()` is called
**Then** it POSTs to `/api/heroes` with hero data
**And** no direct OpenAI API calls are made
**And** the avatar generation is requested via `POST /api/heroes/[id]/avatar`
**And** the backend handles all OpenAI interactions

#### Scenario: Illustration placeholder shows loading state
- **WHEN** an illustration is not yet generated
- **THEN** the placeholder view displays a loading/generating indicator (e.g., spinner with "Generating illustration...")
- **AND** the text "Coming Soon" does NOT appear

#### Scenario: StoryRepository generates story via backend

**Given** a user wants to generate a story
**When** `StoryRepository.generateStory()` is called
**Then** it POSTs to `/api/stories` with story parameters
**And** no direct OpenAI API calls are made
**And** the backend generates story content, audio, and illustrations
**And** the iOS app receives URLs for media files (R2 storage)

#### Scenario: StoryRepository handles async operations

**Given** a story generation is in progress
**When** `StoryRepository.generateIllustrations()` is called
**Then** it POSTs to `/api/stories/[id]/illustrations`
**And** it polls `/api/stories/[id]/illustrations/status` for progress
**And** the UI shows progress updates
**And** on completion, illustration URLs are returned

### Requirement: ViewModels Must Use Repositories Exclusively

ViewModels SHALL NOT directly reference AIService or OpenAI code. All AI operations MUST go through repositories.

#### Scenario: StoryViewModel generates story without AIService

**Given** StoryViewModel is initialized
**When** the user generates a story
**Then** `storyRepository.generateStory()` is called
**And** no `AIService` methods are invoked
**And** no direct OpenAI SDK calls are made
**And** the story is generated successfully via backend

#### Scenario: StoryViewModel generates audio without AIService

**Given** a story exists without audio
**When** the user requests audio generation
**Then** `storyRepository.generateAudio()` is called
**And** no `AIService.generateAudio()` is invoked
**And** the audio URL is fetched from backend
**And** the audio is downloaded and cached via URLCache

### Requirement: iOS Must Support Sign in with Apple

The iOS app SHALL provide native Sign in with Apple authentication using the AuthenticationServices framework.

#### Scenario: User taps Sign in with Apple button

- **GIVEN** a user is on the AuthenticationView
- **WHEN** the user taps the "Sign in with Apple" button
- **THEN** the system Apple authentication sheet is presented
- **AND** the user can authenticate with Face ID, Touch ID, or passcode
- **AND** the app requests email and full name scopes

#### Scenario: Apple authentication succeeds

- **GIVEN** a user has completed Apple authentication
- **AND** Apple returns a valid authorization with ID token
- **WHEN** the iOS app receives the credential
- **THEN** the app sends the ID token to the backend `/api/auth/sign-in/social`
- **AND** on success, AuthStateManager stores the session token in Keychain
- **AND** the app navigates to ImprovedContentView
- **AND** success haptic feedback is triggered

#### Scenario: Apple authentication is cancelled by user

- **GIVEN** a user is presented with the Apple authentication sheet
- **WHEN** the user taps "Cancel" or dismisses the sheet
- **THEN** the app returns to AuthenticationView
- **AND** no error message is shown (cancellation is intentional)
- **AND** the user can try again or use email/password

#### Scenario: Apple authentication fails due to error

- **GIVEN** a user attempts to sign in with Apple
- **WHEN** Apple authentication fails (network error, invalid state, etc.)
- **THEN** the app shows a user-friendly error alert
- **AND** error haptic feedback is triggered
- **AND** the user remains on AuthenticationView
- **AND** the user can retry

#### Scenario: First-time Apple sign-in captures user info

- **GIVEN** a user signs in with Apple for the first time
- **AND** Apple provides user's full name and email
- **WHEN** the app processes the authorization
- **THEN** the user's name is extracted from the credential
- **AND** the name is sent to the backend for user creation
- **AND** subsequent sign-ins may not include the name (Apple only sends it once)

### Requirement: Sign in with Apple Button Must Follow Apple Guidelines

The Sign in with Apple button SHALL conform to Apple Human Interface Guidelines for placement, styling, and behavior.

#### Scenario: Apple button uses system-provided style

- **GIVEN** the AuthenticationView is displayed
- **WHEN** the Sign in with Apple button is rendered
- **THEN** the button uses `SignInWithAppleButton` from AuthenticationServices
- **AND** the button style matches the app's color scheme (`.black` for light mode, `.white` for dark mode)
- **AND** the button has minimum 44pt touch target height

#### Scenario: Apple button is prominently displayed

- **GIVEN** the AuthenticationView is displayed
- **WHEN** the user views authentication options
- **THEN** the Sign in with Apple button is displayed prominently
- **AND** the button is positioned above or alongside email/password options
- **AND** the button is clearly visible and accessible

### Requirement: Auth Flow Must Be Complete

The iOS app SHALL provide a complete sign-up, sign-in, and Sign in with Apple flow with proper error handling.

#### Scenario: User signs up successfully

**Given** a new user on the AuthenticationView
**When** the user enters email "newuser@example.com" and password "SecurePass123"
**And** taps "Sign Up"
**Then** APIClient POSTs to `/api/auth/sign-up`
**And** on success, AuthStateManager stores the session token in Keychain
**And** the app navigates to ImprovedContentView
**And** the user can immediately use the app

#### Scenario: User signs in successfully

**Given** an existing user on the AuthenticationView
**When** the user enters valid credentials and taps "Sign In"
**Then** APIClient POSTs to `/api/auth/sign-in`
**And** on success, the session token is stored
**And** the app navigates to the main interface
**And** all subsequent API calls include the auth token

#### Scenario: User signs in with Apple successfully

**Given** a user on the AuthenticationView
**When** the user taps "Sign in with Apple" and completes authentication
**Then** the app receives an Apple ID token
**And** the app POSTs to `/api/auth/sign-in/social` with the token
**And** on success, the session token is stored
**And** the app navigates to ImprovedContentView

#### Scenario: Sign-in fails with invalid credentials

**Given** a user on the AuthenticationView
**When** the user enters incorrect password and taps "Sign In"
**Then** the API returns 401 Unauthorized
**And** the app shows an alert: "Invalid email or password"
**And** the user remains on AuthenticationView
**And** the user can retry

#### Scenario: Sign-in fails due to network error

**Given** a user on AuthenticationView
**And** the device has no internet connection
**When** the user taps "Sign In" or "Sign in with Apple"
**Then** the app shows an alert: "Network error. Please check your connection."
**And** the user can retry when connection is restored

### Requirement: App Entry Must Check Auth State

The app SHALL show AuthenticationView for unauthenticated users and ImprovedContentView for authenticated users.

#### Scenario: First launch shows auth view

**Given** the app is launched for the first time
**And** no session token exists in Keychain
**When** InfiniteStoriesApp initializes
**Then** AuthStateManager.isAuthenticated is false
**And** AuthenticationView is displayed
**And** the user cannot access the main app

#### Scenario: Subsequent launch with valid session

**Given** the app was previously used
**And** a valid session token exists in Keychain
**When** InfiniteStoriesApp initializes
**Then** AuthStateManager.isAuthenticated is true
**And** ImprovedContentView is displayed
**And** the user can immediately use the app

#### Scenario: Session expiry requires re-authentication

**Given** the app is running with an active session
**When** the session token expires
**And** the next API call returns 401 Unauthorized
**Then** AuthStateManager.signOut() is called
**And** the app navigates back to AuthenticationView
**And** the user must sign in again

