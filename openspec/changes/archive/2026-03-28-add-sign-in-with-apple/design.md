## Context

InfiniteStories currently supports email/password authentication via Better Auth. To meet Apple App Store requirements and provide a seamless iOS experience, we need to add Sign in with Apple as an authentication method.

**Stakeholders**: iOS users, App Store Review team, Backend team
**Constraints**: Apple does not support localhost for OAuth callbacks; native iOS flow uses ID Token instead of redirect-based OAuth

## Goals / Non-Goals

**Goals:**
- Provide native Sign in with Apple button on iOS AuthenticationView
- Use ID Token flow (not OAuth redirect) for seamless native experience
- Link Apple accounts with existing email accounts when emails match
- Store Apple provider credentials securely on backend

**Non-Goals:**
- Web-based Sign in with Apple (requires TLS domain, not needed for mobile-only app)
- Supporting other social providers at this time
- Handling Apple private relay email addresses specially (treat as normal emails)

## Decisions

### Decision 1: Use Native ID Token Flow

**What**: Use `ASAuthorizationController` on iOS to get Apple ID Token, send to backend for verification via Better Auth's `signIn.social({ provider: "apple", idToken: {...} })` equivalent endpoint.

**Why**:
- OAuth redirect flow requires HTTPS domain (no localhost)
- ID Token flow provides better UX (no browser redirect)
- Better Auth natively supports ID Token authentication for Apple

**Alternatives considered**:
- OAuth redirect flow: Rejected due to HTTPS requirement and poor UX
- Direct JWT validation on iOS: Rejected as it bypasses backend security and session management

### Decision 2: Bundle ID as Client ID for iOS

**What**: Use the app's Bundle ID (`com.infinitestories.app`) as the client ID for Apple authentication, not the Service ID.

**Why**: Apple's native iOS authentication uses the App ID (Bundle ID) for token validation, not the web Service ID.

### Decision 3: Account Linking Strategy

**What**: Link Apple accounts to existing email accounts when the email matches, using Better Auth's account linking feature.

**Why**: Users may have signed up with email before Apple sign-in was available; seamless linking prevents duplicate accounts.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Apple credential rotation (6-month key expiry) | Document in DEPLOYMENT.md, add calendar reminder for key rotation |
| Users hiding email (Apple private relay) | Accept private relay emails as valid; users can still use the app |
| Account linking conflicts | Better Auth handles this; if email doesn't match any account, create new account |

## Migration Plan

1. Backend: Add Apple provider configuration (no schema changes needed)
2. iOS: Add Sign in with Apple capability in Xcode
3. iOS: Add Apple sign-in button and AuthenticationServices integration
4. Testing: Verify with Apple Sandbox accounts
5. Rollback: Feature is additive; can be disabled by removing provider config

## Open Questions

- [ ] Confirm Apple Developer account has Sign in with Apple capability enabled
- [ ] Decide Bundle ID if not already finalized (assume: `com.infinitestories.app`)
