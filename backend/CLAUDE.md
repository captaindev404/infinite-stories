# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **Firebase Functions backend** for the InfiniteStories iOS app - the primary backend for all new development. The project is migrating from the legacy **Supabase backend** located at `../infinite-stories-backend/`.

**Important**: All new feature development should happen in this Firebase backend. The Supabase backend is being phased out and should only be used for reference during migration.

## Development Tools

### PRD Tool - Task Management for Complex Features

For complex backend features or multi-agent coordination, use the PRD tool located at `../tools/prd/`:

```bash
# Build the tool (from project root)
cd ../tools/prd && cargo build --release

# Create backend task
./target/release/prd create "Implement Cloud Function X" --priority high

# Use Rust library for programmatic access
# See ../tools/prd/README.md for examples
```

**When to use PRD for backend work:**
- Implementing multiple Cloud Functions
- Database migrations with multiple steps
- Backend API changes requiring coordination with iOS team
- Breaking down large refactoring tasks

See [../tools/prd/README.md](../tools/prd/README.md) for complete documentation.

## Directory Structure

```
backend/
├── functions/              # Firebase Cloud Functions
│   ├── src/
│   │   └── index.ts       # Main entry point (mostly boilerplate)
│   ├── package.json       # Node.js dependencies
│   ├── tsconfig.json      # TypeScript configuration
│   └── .eslintrc.js      # ESLint configuration
├── firestore.rules        # Firestore security rules
└── firestore.indexes.json # Firestore database indexes
```

## Development Commands

### Firebase Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Lint code
npm run lint

# Build TypeScript
npm run build

# Watch mode for development
npm run build:watch

# Run Firebase emulator
npm run serve

# Deploy functions to Firebase
npm run deploy

# View function logs
npm run logs
```

### Firebase CLI

```bash
# Start Firebase emulators
firebase emulators:start

# Deploy to Firebase
firebase deploy

# Deploy only functions
firebase deploy --only functions

# View logs
firebase functions:log
```

## Technology Stack

- **Runtime**: Node.js 22
- **Language**: TypeScript 5.7+
- **Functions**: Firebase Functions v6
- **Admin SDK**: Firebase Admin v12
- **Linting**: ESLint with Google config

## Architecture Notes

### Current State
- Active Firebase backend development in progress
- Cloud Functions being implemented for story generation, audio synthesis, and image generation
- Firestore database replacing PostgreSQL
- Firebase Auth replacing Supabase Auth
- Firebase Storage replacing Supabase Storage

### Legacy Backend (Supabase)
The legacy backend logic is in `../infinite-stories-backend/` which is being deprecated:
- **Edge Functions**: Story generation, audio synthesis, avatar generation, scene illustration (to be migrated)
- **Database**: PostgreSQL with comprehensive schema (migrating to Firestore)
- **Storage**: Supabase Storage for media files (migrating to Firebase Storage)
- **Authentication**: Supabase Auth with RLS policies (migrating to Firebase Auth)
- **Content Safety**: Multi-layer content filtering system (to be ported to Firebase)

## Firestore Security Rules

**Current Status**: Development rules are in place - production rules needed for launch

```javascript
// Current rules allow all read/write until expiration
match /{document=**} {
  allow read, write: if request.time < timestamp.date(2025, 10, 17);
}
```

**Action Required**:
- Implement production security rules with proper authentication
- Add user-level authorization (users can only access their own data)
- Implement role-based access control if needed
- Test rules thoroughly with Firebase emulator before deploying

## Migration Status

The project is migrating from Supabase to Firebase:

1. **TODO - High Priority**:
   - Migrate story generation Cloud Function from Supabase Edge Function
   - Migrate audio synthesis Cloud Function (TTS with gpt-4o-mini-tts)
   - Migrate avatar generation Cloud Function (GPT-5 with visual consistency)
   - Migrate scene illustration Cloud Function (batch processing)
   - Port content safety and filtering system to Firebase Functions
   - Migrate database schema from PostgreSQL to Firestore
   - Migrate user authentication from Supabase Auth to Firebase Auth
   - Migrate storage from Supabase Storage to Firebase Storage

2. **In Progress**:
   - Firebase Functions backend infrastructure setup
   - Security rules configuration
   - Development environment setup

3. **Completed**:
   - Firebase project initialization
   - Basic Cloud Functions boilerplate
   - TypeScript configuration
   - Development tooling (ESLint, build scripts)

## Working with This Backend

### When to Use Firebase Backend (Primary)
- **All new feature development**
- Story generation and AI features
- Audio synthesis and TTS
- Image generation (avatars and scenes)
- Content safety and filtering
- User authentication and data storage
- Cloud Functions development
- Firestore database operations
- Firebase Storage operations

### When to Use Supabase Backend (Legacy - Reference Only)
- Reference existing implementations during migration
- Understanding current business logic
- Temporary fallback during transition period
- **Do NOT add new features to Supabase backend**

## Integration with iOS App

The iOS app is transitioning to use this Firebase backend for:
- Story generation with GPT-5 (`gpt-5`) and configurable reasoning
- Audio synthesis with gpt-4o-mini-tts and enhanced voice quality
- Avatar generation with GPT-5 and visual consistency
- Scene illustration with batch processing
- Content filtering and safety
- User authentication via Firebase Auth
- Data persistence via Firestore
- Media storage via Firebase Storage

**Migration Notes**:
- iOS app currently uses Supabase backend during transition
- Update iOS app to use Firebase SDK after Cloud Functions are migrated
- Implement Firebase Auth in iOS app to replace Supabase Auth
- Update data models to work with Firestore instead of PostgreSQL

## Related Documentation

For comprehensive backend documentation, see:
- `./CLAUDE.md` (this file) - Primary Firebase backend development guide
- `../infinite-stories-backend/CLAUDE.md` - Legacy Supabase backend (reference only)
- `../infinite-stories-backend/DEPLOYMENT.md` - Legacy deployment procedures (to be updated for Firebase)
- `../ARCHITECTURE.md` - System architecture overview (update for Firebase migration)
- `../DEVELOPER_GUIDE.md` - iOS app development guide (update for Firebase SDK)

## Security Considerations

⚠️ **Critical Security Requirements**:

1. **Firestore Rules**:
   - Implement production-ready security rules before launch
   - Use Firebase Auth to restrict access to user-owned data
   - Add field-level validation rules
   - Test rules with Firebase emulator and unit tests
   - Update before 2025-10-17 expiration

2. **Firebase Auth**:
   - Configure appropriate auth providers (email/password, OAuth, etc.)
   - Implement proper token validation in Cloud Functions
   - Set up auth triggers for user lifecycle management
   - Configure password policies and MFA if needed

3. **Cloud Functions Security**:
   - Validate all inputs to prevent injection attacks
   - Implement rate limiting to prevent abuse
   - Use Firebase Admin SDK for server-side operations
   - Never expose API keys or credentials in function code
   - Implement proper CORS policies for callable functions

4. **API Keys and Secrets**:
   - Never commit API keys or secrets to version control
   - Use Firebase Functions environment configuration: `firebase functions:config:set`
   - Store OpenAI API keys securely in Firebase config
   - Rotate keys regularly
   - Use Secret Manager for production secrets

5. **Content Safety**:
   - Port existing content filtering system from Supabase
   - Implement input validation and sanitization
   - Monitor for inappropriate content generation
   - Add abuse detection and user reporting

## Migration Path from Supabase to Firebase

### Phase 1: Backend Migration
1. **Set up Firebase infrastructure**:
   - Configure Firebase project settings
   - Set up authentication providers
   - Configure Firestore databases
   - Set up Firebase Storage buckets

2. **Migrate Cloud Functions**:
   - Port story generation Edge Function → Cloud Function
   - Port audio synthesis Edge Function → Cloud Function
   - Port avatar generation Edge Function → Cloud Function
   - Port scene illustration Edge Function → Cloud Function
   - Port content safety system to Cloud Functions
   - Test each function thoroughly with Firebase emulator

3. **Migrate Database Schema**:
   - Design Firestore collections to replace PostgreSQL tables
   - Consider denormalization for Firestore (NoSQL paradigm)
   - Migrate existing data if needed
   - Update security rules for new schema

4. **Migrate Storage**:
   - Set up Firebase Storage buckets
   - Configure storage security rules
   - Migrate existing media files if needed
   - Update URLs and references

### Phase 2: iOS App Migration
1. **Add Firebase SDK**:
   - Install Firebase iOS SDK via SPM
   - Configure GoogleService-Info.plist
   - Initialize Firebase in app

2. **Replace Supabase Auth with Firebase Auth**:
   - Implement Firebase Auth sign-in flows
   - Update user session management
   - Migrate user accounts or require re-authentication

3. **Replace Supabase SDK calls with Firebase SDK**:
   - Update story generation to call Firebase Cloud Functions
   - Update data models for Firestore
   - Replace Supabase Storage with Firebase Storage
   - Update all API calls

4. **Testing**:
   - Test all features with Firebase backend
   - Verify authentication flows
   - Test data persistence
   - Verify media uploads and downloads

### Phase 3: Cleanup
1. **Decommission Supabase**:
   - Archive Supabase backend code
   - Export any necessary data
   - Cancel Supabase subscription
   - Remove Supabase dependencies from iOS app

2. **Update Documentation**:
   - Update all README files
   - Update deployment procedures
   - Update architecture diagrams
   - Document Firebase setup for new developers

### Key Considerations
- **Data Migration**: Determine if user data needs to be migrated or if users start fresh
- **API Keys**: Securely configure OpenAI and other API keys in Firebase
- **Rate Limiting**: Implement proper rate limiting in Cloud Functions
- **Cost**: Monitor Firebase usage to optimize costs
- **Backward Compatibility**: Consider dual-backend support during transition if needed

## Commands Reference

### Essential Firebase Commands
```bash
# Build and test locally
cd functions && npm run build && npm run serve

# Start Firebase emulators (recommended for development)
firebase emulators:start

# Deploy to Firebase
firebase deploy

# Deploy only functions
firebase deploy --only functions

# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy only Storage rules
firebase deploy --only storage

# View function logs
firebase functions:log

# View logs for specific function
firebase functions:log --only functionName

# Set environment config
firebase functions:config:set openai.key="YOUR_KEY"

# Get environment config
firebase functions:config:get

# Test Firestore security rules
firebase emulators:exec --only firestore "npm test"
```

### Development Workflow Commands
```bash
# Watch mode for TypeScript compilation
cd functions && npm run build:watch

# Lint code
cd functions && npm run lint

# Run functions locally
cd functions && npm run serve
```

### Legacy Supabase Backend (Reference Only)
```bash
# View legacy Supabase implementation
cd ../infinite-stories-backend

# Reference Supabase Edge Functions (DO NOT deploy)
ls supabase/functions/
```

## Development Workflow

### Primary Workflow (Firebase)
1. **Start Development**:
   ```bash
   cd functions
   npm install
   npm run build:watch  # Terminal 1: Watch TypeScript compilation
   ```

2. **Local Testing**:
   ```bash
   firebase emulators:start  # Terminal 2: Run Firebase emulators
   # Test functions at http://localhost:5001
   # Access Firestore UI at http://localhost:4000
   ```

3. **Write Cloud Functions**:
   - Create functions in `functions/src/`
   - Use Firebase Admin SDK for Firestore/Auth/Storage operations
   - Implement proper error handling and logging
   - Add input validation and security checks

4. **Test Thoroughly**:
   - Test with Firebase emulator
   - Write unit tests for functions
   - Test Firestore security rules
   - Verify authentication flows

5. **Deploy**:
   ```bash
   npm run build
   npm run lint
   firebase deploy --only functions
   ```

### Reference Legacy Implementation (Supabase)
1. **View Existing Logic**:
   ```bash
   cd ../infinite-stories-backend
   # Study Edge Functions for migration reference
   cat supabase/functions/story-generation/index.ts
   ```

2. **Do NOT modify or deploy Supabase code**
   - Only use for reference during migration
   - Port logic to Firebase Cloud Functions

## Notes for Future Development

### High Priority
- **Implement Cloud Functions**: Port all Supabase Edge Functions to Firebase Cloud Functions
- **Security Rules**: Update Firestore and Storage security rules before 2025-10-17
- **Firebase Auth**: Implement user authentication to replace Supabase Auth
- **Database Schema**: Design and implement Firestore collections
- **iOS App Integration**: Update iOS app to use Firebase SDK

### Migration Strategy
- Maintain feature parity with Supabase during transition
- Test thoroughly with Firebase emulators before deployment
- Consider phased rollout with feature flags if needed
- Monitor Firebase usage and costs closely

### Long-term Considerations
- Archive Supabase backend code after complete migration
- Remove all Supabase dependencies from iOS app
- Update all documentation to reflect Firebase architecture
- Set up monitoring and alerting for Cloud Functions
- Implement proper backup and disaster recovery procedures
- Plan for scaling Cloud Functions based on user growth

### Key Features to Migrate
1. **Story Generation**: GPT-5 integration with configurable reasoning
2. **Audio Synthesis**: TTS with gpt-4o-mini-tts
3. **Avatar Generation**: GPT-5 with visual consistency tracking
4. **Scene Illustration**: Batch processing and image generation
5. **Content Safety**: Multi-layer filtering and validation
6. **User Management**: Auth, profiles, and data persistence
