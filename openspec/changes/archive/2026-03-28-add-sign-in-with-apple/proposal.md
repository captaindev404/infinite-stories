# Change: Add Sign in with Apple Authentication

## Why

Apple requires iOS apps that offer third-party sign-in options to also provide Sign in with Apple. Additionally, Sign in with Apple offers a seamless, privacy-focused authentication experience that iOS users expect, reducing friction during onboarding and increasing conversion rates.

## What Changes

- **Backend**: Configure Better Auth with Apple social provider using Service ID, Team ID, and Key ID credentials
- **Backend**: Add endpoint to handle Apple ID Token authentication for native iOS flow
- **iOS App**: Integrate AuthenticationServices framework for native Sign in with Apple button
- **iOS App**: Handle Apple credential flow and send ID token to backend for verification
- **Account Linking**: Enable linking Apple accounts with existing email accounts

## Impact

- Affected specs: `backend-auth`, `ios-integration`
- Affected code:
  - `infinite-stories-backend/lib/auth/auth.ts` - Add Apple provider configuration
  - `infinite-stories-ios/InfiniteStories/Views/Auth/AuthenticationView.swift` - Add Apple sign-in button
  - `infinite-stories-ios/InfiniteStories/Services/AuthStateManager.swift` - Handle Apple auth state
  - Xcode project entitlements - Add Sign in with Apple capability
