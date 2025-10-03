# Firebase iOS Configuration Guide

## Current Status ✅

Firebase has been successfully initialized in the InfiniteStories iOS app with the following configuration:

- **Project ID**: `infinite-stories-5a980`
- **Bundle ID**: `com.captaindev.InfiniteStories`
- **GoogleService-Info.plist**: ✅ Configured and present in project
- **Firebase Core**: ✅ Initialized in `InfiniteStoriesApp.swift`
- **FirebaseConfig Helper**: ✅ Created at `Services/FirebaseConfig.swift`

## Firebase Initialization

Firebase is automatically initialized when the app launches:

```swift
// InfiniteStoriesApp.swift
init() {
    // Initialize Firebase
    FirebaseApp.configure()
    print("🔥 Firebase initialized successfully")
}
```

## Next Steps for Full Firebase Integration

### 1. Add Required Firebase Modules

The project currently only has Firebase Core. To enable full functionality, add these modules via Xcode Package Manager:

1. Open `InfiniteStories.xcodeproj` in Xcode
2. Go to File → Add Package Dependencies
3. Add the Firebase iOS SDK if not already present
4. Select these modules:
   - ✅ FirebaseCore (already added)
   - ⬜ FirebaseAuth (for authentication)
   - ⬜ FirebaseFirestore (for database)
   - ⬜ FirebaseStorage (for file storage)
   - ⬜ FirebaseFunctions (for cloud functions)
   - ⬜ FirebaseAnalytics (optional, for analytics)

### 2. Enable Firebase Services in Console

Visit [Firebase Console](https://console.firebase.google.com/project/infinite-stories-5a980) and enable:

1. **Authentication**:
   - Enable Email/Password provider
   - Configure sign-in methods
   - Set up auth domains

2. **Firestore Database**:
   - Create database in production mode
   - Configure security rules
   - Set up indexes

3. **Storage**:
   - Create default storage bucket
   - Configure storage rules
   - Set up CORS if needed

4. **Cloud Functions**:
   - Initialize functions
   - Deploy story generation functions
   - Set up environment variables

### 3. Update Firebase Service Files

Once modules are added, uncomment and update these files:

- `Services/FirebaseConfig.swift` - Uncomment service properties
- `Services/FirebaseAuthService.swift` - Enable authentication methods
- `Services/FirebaseAIService.swift` - Enable AI service integration
- `Services/AuthMigrationHelper.swift` - Enable migration logic

### 4. Configure Security Rules

Update Firestore rules (currently expire on 2025-10-17):

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User data - users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Stories - users can only access their own stories
    match /stories/{storyId} {
      allow read, write: if request.auth != null &&
        request.auth.uid == resource.data.userId;
    }

    // Heroes - users can only access their own heroes
    match /heroes/{heroId} {
      allow read, write: if request.auth != null &&
        request.auth.uid == resource.data.userId;
    }
  }
}
```

### 5. Migration Path from Supabase

The app is configured to support dual authentication during migration:

1. **Phase 1**: Both Supabase and Firebase active (current state)
2. **Phase 2**: Migrate user data from Supabase to Firestore
3. **Phase 3**: Switch authentication to Firebase
4. **Phase 4**: Decommission Supabase

## Files Modified

1. **InfiniteStoriesApp.swift**:
   - Added `import FirebaseCore`
   - Added `FirebaseApp.configure()` in init()

2. **Services/FirebaseConfig.swift** (new):
   - Firebase service management
   - Configuration helpers
   - Future integration points documented

3. **GoogleService-Info.plist**:
   - Already configured for project
   - Contains API keys and project settings

## Testing Firebase Configuration

Run this code to verify Firebase is configured:

```swift
// Add to any view for testing
.onAppear {
    if FirebaseConfig.shared.verifyConfiguration() {
        print("✅ Firebase is properly configured")
        print(FirebaseConfig.shared.getConfigurationSummary())
    }
}
```

## Important Notes

- **DO NOT** remove Supabase initialization yet - both systems run in parallel
- Firebase modules are added incrementally as needed
- The app will continue to use Supabase until migration is complete
- All Firebase service files are prepared but commented until modules are added

## Error Handling

If you see build errors related to Firebase:

1. Ensure GoogleService-Info.plist is in the project
2. Clean build folder: Cmd+Shift+K
3. Reset package caches: File → Packages → Reset Package Caches
4. Rebuild the project

## Support

For Firebase setup issues:
- [Firebase iOS Setup Guide](https://firebase.google.com/docs/ios/setup)
- [Firebase Console](https://console.firebase.google.com/project/infinite-stories-5a980)
- Check `firebase-debug.log` for Firebase CLI issues