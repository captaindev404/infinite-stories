## 1. Apple Developer Portal Setup

- [x] 1.1 Create App ID with Sign in with Apple capability enabled
- [ ] 1.2 Create Service ID for backend OAuth callbacks (for future web support)
- [x] 1.3 Generate and download `.p8` private key file
- [x] 1.4 Record Team ID, Key ID, and Bundle ID
- [ ] 1.5 Document credential rotation schedule in DEPLOYMENT.md

## 2. Backend Configuration

- [x] 2.1 Add Apple provider environment variables to `.env.example` and Dokploy secrets
- [x] 2.2 Configure Better Auth with Apple social provider in `lib/auth/auth.ts`
- [x] 2.3 Add `appBundleIdentifier` for native iOS ID Token validation
- [x] 2.4 Add `appleid.apple.com` to trusted origins
- [x] 2.5 Test Apple provider configuration on device

## 3. iOS Xcode Project Setup

- [x] 3.1 Add "Sign in with Apple" capability in Xcode project
- [x] 3.2 Add `AuthenticationServices` framework import
- [x] 3.3 Update entitlements file with Sign in with Apple entitlement

## 4. iOS Authentication Implementation

- [x] 4.1 Handle ASAuthorization inline in AuthenticationView
- [x] 4.2 Implement credential handling via handleAppleSignIn method
- [x] 4.3 Add method to send Apple ID token to backend for verification
- [x] 4.4 Handle Apple user info (email, name) from first-time authorization
- [x] 4.5 Apple user identifier stored via backend session (Keychain token)

## 5. iOS UI Integration

- [x] 5.1 Add `SignInWithAppleButton` to AuthenticationView
- [x] 5.2 Style button according to Apple Human Interface Guidelines
- [x] 5.3 Add loading state during Apple authentication
- [x] 5.4 Handle Apple sign-in errors with user-friendly messages
- [x] 5.5 Add haptic feedback for Apple sign-in success/failure

## 6. Account Linking

- [x] 6.1 Configure Better Auth account linking for Apple provider
- [x] 6.2 Test on physical device - Apple sign-in sheet appears and authenticates
- [x] 6.3 Test creating new account via Apple - backend creates user and returns session

## 7. Deployment

- [x] 7.1 Deploy Apple credentials to dev/staging/prod Dokploy environments
- [x] 7.2 Test sign-in flow on physical iOS device - verified working
- [x] 7.3 Test error handling (user cancellation does not show error)
- [x] 7.4 Verify idToken format (object with token/name fields for Better Auth)
- [x] 7.5 Push code and deploy all environments

## Credentials Reference

- **Team ID**: 98395466N2
- **Key ID**: PJ74ZJSU5Z
- **Bundle ID**: com.captaindev.InfiniteStories
- **Private Key**: `AuthKey_PJ74ZJSU5Z.p8` (project root, gitignored)
- **Client Secret**: JWT generated from .p8 key (expires 2026-09-21)
