## ADDED Requirements

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

## MODIFIED Requirements

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
