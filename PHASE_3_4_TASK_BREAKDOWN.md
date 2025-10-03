# Phase 3-4 Task Breakdown: Model Updates & iOS Integration

## Overview
This document provides a detailed task breakdown for Phases 3-4 of the Supabase to Firebase migration, covering Model Updates (Week 3) and iOS Integration (Week 4).

## Phase 3: Model Updates & Data Migration (Week 3)

### 3.1 Model Codable Updates

#### Task 3.1.1: Update Hero Model for Firestore
- **Title**: Add Firestore-compatible Codable to Hero model
- **Description**: Update Hero.swift to include custom Codable implementation with UUID/String conversion, Date/Timestamp conversion, and toFirestoreData()/fromFirestoreData() methods
- **Priority**: Critical
- **Duration**: 2 hours
- **Dependencies**: None
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Hero model has custom CodingKeys enum
  - toFirestoreData() method converts Hero to dictionary
  - fromFirestoreData() initializer creates Hero from dictionary
  - UUID fields properly converted to/from strings
  - Dates converted to/from Firestore Timestamps

#### Task 3.1.2: Update Story Model for Firestore
- **Title**: Add Firestore-compatible Codable to Story model
- **Description**: Update Story.swift with Firestore serialization, handle hero references, event data mapping, and nested objects
- **Priority**: Critical
- **Duration**: 3 hours
- **Dependencies**: Task 3.1.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Story model handles DocumentReference for heroId
  - Event data properly serialized as nested map
  - Audio/illustration URLs handled correctly
  - Scene count and duration preserved

#### Task 3.1.3: Update CustomStoryEvent Model
- **Title**: Add Firestore-compatible Codable to CustomStoryEvent model
- **Description**: Update CustomStoryEvent.swift for Firestore compatibility with keywords array handling
- **Priority**: High
- **Duration**: 1.5 hours
- **Dependencies**: Task 3.1.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Keywords array properly serialized
  - Boolean fields (isFavorite) handled
  - Usage count tracking maintained

#### Task 3.1.4: Update StoryIllustration Model
- **Title**: Add Firestore-compatible Codable to StoryIllustration model
- **Description**: Update StoryIllustration.swift for Firestore subcollection storage
- **Priority**: High
- **Duration**: 1 hour
- **Dependencies**: Task 3.1.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Scene number mapping correct
  - Image URL handling implemented
  - Generation ID preserved

#### Task 3.1.5: Create Model Helper Extensions
- **Title**: Implement Firestore helper methods for all models
- **Description**: Create Extensions/FirestoreHelpers.swift with common conversion utilities
- **Priority**: High
- **Duration**: 2 hours
- **Dependencies**: Tasks 3.1.1-3.1.4
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - UUID to String conversion helpers
  - Date to Timestamp conversion helpers
  - Optional field handling utilities
  - Error handling for invalid data

### 3.2 Data Migration Scripts

#### Task 3.2.1: Assess Production Data
- **Title**: Check if production data exists in Supabase
- **Description**: Query Supabase production instance to determine if any user data needs migration
- **Priority**: Critical
- **Duration**: 0.5 hours
- **Dependencies**: None
- **Agent Type**: Backend Engineer
- **Acceptance Criteria**:
  - Document record counts for each table
  - Identify active users
  - Assess data volume for migration

#### Task 3.2.2: Create Hero Migration Script
- **Title**: Implement migrate-heroes.ts script
- **Description**: Create TypeScript script to migrate heroes from Supabase to Firestore with field mapping
- **Priority**: Critical (if data exists)
- **Duration**: 3 hours
- **Dependencies**: Task 3.2.1
- **Agent Type**: Backend Engineer
- **Acceptance Criteria**:
  - All hero fields mapped correctly
  - UUID conversion handled
  - Visual profiles migrated to subcollection
  - Validation of migrated data

#### Task 3.2.3: Create Story Migration Script
- **Title**: Implement migrate-stories.ts script
- **Description**: Create script to migrate stories with hero references and illustrations
- **Priority**: Critical (if data exists)
- **Duration**: 4 hours
- **Dependencies**: Task 3.2.2
- **Agent Type**: Backend Engineer
- **Acceptance Criteria**:
  - Story to hero references maintained
  - Illustrations migrated to subcollections
  - Event data properly nested
  - Audio URLs preserved

#### Task 3.2.4: Create Storage Migration Script
- **Title**: Implement migrate-storage.ts script
- **Description**: Create script to transfer files from Supabase Storage to Firebase Storage
- **Priority**: Critical (if data exists)
- **Duration**: 4 hours
- **Dependencies**: Tasks 3.2.2-3.2.3
- **Agent Type**: Backend Engineer
- **Acceptance Criteria**:
  - Hero avatars transferred with correct paths
  - Story audio files migrated
  - Illustrations moved to proper buckets
  - URLs updated in database records

#### Task 3.2.5: Test Migration Scripts
- **Title**: Test migration scripts with sample data
- **Description**: Run dry-run migration on test data to validate scripts
- **Priority**: Critical
- **Duration**: 2 hours
- **Dependencies**: Tasks 3.2.2-3.2.4
- **Agent Type**: Backend Engineer
- **Acceptance Criteria**:
  - No data loss in test migration
  - Performance acceptable for data volume
  - Rollback procedure tested
  - Error handling verified

## Phase 4: iOS Integration (Week 4)

### 4.1 ViewModel Updates

#### Task 4.1.1: Update HeroViewModel
- **Title**: Replace SupabaseService with FirebaseDataService in HeroViewModel
- **Description**: Update all data operations to use Firebase services through protocol
- **Priority**: Critical
- **Duration**: 2 hours
- **Dependencies**: Phase 2 completion (FirebaseDataService)
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - All CRUD operations using FirebaseDataService
  - Error handling updated for Firebase errors
  - Loading states properly managed
  - No Supabase imports remaining

#### Task 4.1.2: Update StoryViewModel
- **Title**: Replace SupabaseService with Firebase services in StoryViewModel
- **Description**: Update story operations, AI service calls, and storage operations
- **Priority**: Critical
- **Duration**: 3 hours
- **Dependencies**: Task 4.1.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Story generation using FirebaseAIService
  - Audio/illustration storage via FirebaseStorageService
  - Data persistence through FirebaseDataService
  - Proper error propagation

#### Task 4.1.3: Update AuthViewModel
- **Title**: Integrate FirebaseAuthService in AuthViewModel
- **Description**: Replace any Supabase auth logic with Firebase Authentication
- **Priority**: Critical
- **Duration**: 2 hours
- **Dependencies**: Phase 2 (FirebaseAuthService)
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Sign up/sign in flows working
  - Session management implemented
  - Auth state changes handled
  - Error messages user-friendly

#### Task 4.1.4: Update Secondary ViewModels
- **Title**: Update any remaining ViewModels
- **Description**: Search for and update any other ViewModels using SupabaseService
- **Priority**: High
- **Duration**: 2 hours
- **Dependencies**: Tasks 4.1.1-4.1.3
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - All ViewModels checked for Supabase usage
  - Service references updated to Firebase
  - Consistent error handling

### 4.2 View Layer Updates

#### Task 4.2.1: Remove Supabase Imports from Views
- **Title**: Search and remove all 'import Supabase' statements
- **Description**: Use grep to find and remove all Supabase imports from SwiftUI views
- **Priority**: Critical
- **Duration**: 1 hour
- **Dependencies**: Task 4.1.4
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Zero Supabase imports in Views folder
  - Code still compiles after removal
  - No broken references

#### Task 4.2.2: Update Direct Service Usage
- **Title**: Replace direct SupabaseService usage in Views
- **Description**: Find any views directly using SupabaseService and update to use ViewModels
- **Priority**: High
- **Duration**: 2 hours
- **Dependencies**: Task 4.2.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - No direct service access from views
  - All data operations through ViewModels
  - Proper MVVM pattern maintained

### 4.3 App Initialization Updates

#### Task 4.3.1: Update InfiniteStoriesApp.swift
- **Title**: Configure app initialization for Firebase Auth
- **Description**: Add AuthViewModel as StateObject, configure Firestore settings
- **Priority**: Critical
- **Duration**: 1.5 hours
- **Dependencies**: Tasks 4.1.3, 4.2.2
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - AuthViewModel initialized at app level
  - Firestore persistence enabled
  - Cache size configured
  - Auth state determines initial view

#### Task 4.3.2: Implement Auth Flow
- **Title**: Add authentication state observer and routing
- **Description**: Show FirebaseAuthView for unauthenticated users, ContentView for authenticated
- **Priority**: Critical
- **Duration**: 2 hours
- **Dependencies**: Task 4.3.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Unauthenticated users see login screen
  - Authenticated users see main app
  - Smooth transitions between states
  - Session persistence working

### 4.4 Dependency Removal

#### Task 4.4.1: Remove Supabase Package Dependencies
- **Title**: Remove all Supabase-related packages from Xcode project
- **Description**: Use Xcode to remove package dependencies for supabase-swift and related packages
- **Priority**: Critical
- **Duration**: 1 hour
- **Dependencies**: All previous tasks in Phase 4
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - supabase-swift removed
  - postgrest-swift removed
  - realtime-swift removed
  - storage-swift removed
  - functions-swift removed
  - gotrue-swift removed
  - Project builds successfully

#### Task 4.4.2: Verify Clean Package.resolved
- **Title**: Verify Package.resolved has no Supabase references
- **Description**: Check Package.resolved file to ensure complete removal
- **Priority**: High
- **Duration**: 0.5 hours
- **Dependencies**: Task 4.4.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - Package.resolved contains no Supabase packages
  - Only Firebase packages remain
  - Git shows clean removal

### 4.5 File Deletion

#### Task 4.5.1: Delete Supabase Service Files
- **Title**: Remove all Supabase-related Swift files
- **Description**: Delete SupabaseService.swift, SupabaseAIService.swift, SupabaseConfig.swift, SupabaseHelpers.swift
- **Priority**: Critical
- **Duration**: 0.5 hours
- **Dependencies**: Task 4.4.2
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - All Supabase service files deleted
  - Project still compiles
  - No broken references
  - Git tracking deletions

#### Task 4.5.2: Final Verification
- **Title**: Verify no remaining Supabase imports in codebase
- **Description**: Run comprehensive grep search to ensure complete removal
- **Priority**: Critical
- **Duration**: 0.5 hours
- **Dependencies**: Task 4.5.1
- **Agent Type**: iOS Engineer
- **Acceptance Criteria**:
  - grep finds zero Supabase imports
  - No Supabase string literals remain
  - Clean build with no warnings

## Summary Statistics

### Phase 3 (Model Updates & Migration)
- **Total Tasks**: 10
- **Total Duration**: 23.5 hours
- **Critical Tasks**: 6
- **High Priority Tasks**: 4

### Phase 4 (iOS Integration)
- **Total Tasks**: 12
- **Total Duration**: 20 hours
- **Critical Tasks**: 9
- **High Priority Tasks**: 3

### Combined Phases 3-4
- **Total Tasks**: 22
- **Total Duration**: 43.5 hours (~5.5 days)
- **Critical Tasks**: 15 (68%)
- **High Priority Tasks**: 7 (32%)

## Task Dependencies Graph

```
Phase 3.1.1 (Hero Model) ──┬──> 3.1.2 (Story Model)
                           ├──> 3.1.3 (CustomEvent Model)
                           └──> 3.1.4 (Illustration Model)
                                          │
                                          ▼
                                   3.1.5 (Helper Extensions)

Phase 3.2.1 (Assess Data) ──┬──> 3.2.2 (Migrate Heroes)
                            └──> 3.2.3 (Migrate Stories)
                                          │
                                          ▼
                                   3.2.4 (Migrate Storage)
                                          │
                                          ▼
                                   3.2.5 (Test Migration)

Phase 4.1.1 (HeroViewModel) ──┬──> 4.1.2 (StoryViewModel)
                              └──> 4.1.4 (Other ViewModels)
                                          │
Phase 4.1.3 (AuthViewModel) ─────────────┤
                                          ▼
                                   4.2.1 (Remove Imports)
                                          │
                                          ▼
                                   4.2.2 (Update Views)
                                          │
                                          ▼
                                   4.3.1 (App Init)
                                          │
                                          ▼
                                   4.3.2 (Auth Flow)
                                          │
                                          ▼
                                   4.4.1 (Remove Packages)
                                          │
                                          ▼
                                   4.4.2 (Verify Packages)
                                          │
                                          ▼
                                   4.5.1 (Delete Files)
                                          │
                                          ▼
                                   4.5.2 (Final Verification)
```

## Risk Mitigation for Phases 3-4

### High Risk Areas
1. **Model Serialization Errors**: Test thoroughly with sample data
2. **Data Migration Failures**: Implement rollback capability
3. **Authentication State Loss**: Test session persistence
4. **Package Removal Breaking Build**: Create backup of project.pbxproj

### Mitigation Strategies
- Create feature branch for all changes
- Test each task independently before moving to next
- Maintain ability to rollback at each checkpoint
- Document all field mappings for reference
- Keep Supabase backup for 30 days minimum

## Success Metrics for Phases 3-4

1. **Code Quality**
   - Zero Supabase imports remaining
   - All models have Firestore serialization
   - 100% of ViewModels updated

2. **Functionality**
   - All CRUD operations working with Firebase
   - Authentication flow complete
   - Data persistence verified

3. **Testing**
   - Unit tests for all model conversions
   - Integration tests for ViewModels
   - UI tests for critical flows

4. **Performance**
   - Model serialization <10ms
   - ViewModel operations <100ms
   - App launch time unchanged

## Next Steps After Phase 4

1. Begin Phase 5: Testing & Validation
2. Run comprehensive test suite
3. Performance benchmarking
4. Security validation
5. User acceptance testing

## Notes for Implementation Team

- **Parallel Work**: Tasks 3.1.x and 3.2.x can be done in parallel by different engineers
- **Checkpoint Reviews**: Review after completing each sub-phase (3.1, 3.2, 4.1, etc.)
- **Documentation**: Update inline documentation as changes are made
- **Version Control**: Commit after each completed task with descriptive message
- **Communication**: Daily standup to track progress and blockers