use anyhow::Result;
use prd_tool::{Database, Priority};

fn main() -> Result<()> {
    let db = Database::new("tools/prd.db")?;

    println!("🚀 Populating Supabase to Firebase Migration Tasks...\n");

    // Create parent task
    let parent = db.create_task(
        "Complete Supabase to Firebase Migration".to_string(),
        Some("Remove all Supabase dependencies from iOS app and migrate to Firebase backend with 100% feature parity".to_string()),
        Priority::Critical,
        None,
    )?;
    println!("✓ Created parent task: {}", parent.id);

    // Phase 1: Foundation & Setup (Week 1)
    let phase1 = db.create_task(
        "Phase 1: Foundation & Setup (Week 1)".to_string(),
        Some("Set up Firebase infrastructure, create service protocols, deploy backend configuration".to_string()),
        Priority::Critical,
        Some(parent.id.clone()),
    )?;
    println!("✓ Created Phase 1: {}", phase1.id);

    // Phase 1.1: Create Service Protocols
    let task_1_1_1 = db.create_task(
        "Create DataServiceProtocol interface".to_string(),
        Some("Define protocol for data operations including Hero, Story, and CustomEvent CRUD operations. File: InfiniteStories/Services/Protocols/DataServiceProtocol.swift".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_1_2 = db.create_task(
        "Create StorageServiceProtocol interface".to_string(),
        Some("Define protocol for storage operations including avatar, audio, and illustration upload/download. File: InfiniteStories/Services/Protocols/StorageServiceProtocol.swift".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_1_3 = db.create_task(
        "Create AuthServiceProtocol interface".to_string(),
        Some("Define protocol for authentication operations. File: InfiniteStories/Services/Protocols/AuthServiceProtocol.swift".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    // Phase 1.2: Update Firebase Configuration
    let task_1_2_1 = db.create_task(
        "Configure Firebase services initialization".to_string(),
        Some("Update FirebaseConfig.swift to add production config, environment detection, and service getters. Depends on protocol creation.".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_2_2 = db.create_task(
        "Validate Firebase configuration files".to_string(),
        Some("Ensure GoogleService-Info.plist is properly configured for production project (infinite-stories-5a980)".to_string()),
        Priority::High,
        Some(phase1.id.clone()),
    )?;

    // Phase 1.3: Firestore Setup
    let task_1_3_1 = db.create_task(
        "Write and deploy Firestore security rules".to_string(),
        Some("Create backend/firestore.rules with comprehensive security for users, heroes, stories, customEvents collections".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_3_2 = db.create_task(
        "Define and deploy Firestore indexes".to_string(),
        Some("Create backend/firestore.indexes.json with required composite indexes for efficient queries".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_3_3 = db.create_task(
        "Deploy Firestore configuration".to_string(),
        Some("Use Firebase CLI to deploy security rules and indexes to production. Command: firebase deploy --only firestore:rules,firestore:indexes".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    // Phase 1.4: Firebase Storage Setup
    let task_1_4_1 = db.create_task(
        "Write and deploy Storage security rules".to_string(),
        Some("Create backend/storage.rules with security for hero-avatars, story-audio, story-illustrations buckets".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_4_2 = db.create_task(
        "Deploy Storage configuration".to_string(),
        Some("Use Firebase CLI to deploy storage security rules. Command: firebase deploy --only storage".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    // Phase 1.5: Verify Backend Deployment
    let task_1_5_1 = db.create_task(
        "Confirm all Cloud Functions deployed".to_string(),
        Some("Verify storyGeneration, audioSynthesis, avatarGeneration, sceneIllustration, extractScenes functions are deployed and responding".to_string()),
        Priority::Critical,
        Some(phase1.id.clone()),
    )?;

    let task_1_5_2 = db.create_task(
        "Confirm Firestore indexes built".to_string(),
        Some("Check Firebase Console to ensure all composite indexes are in READY state. Command: firebase firestore:indexes".to_string()),
        Priority::High,
        Some(phase1.id.clone()),
    )?;

    let task_1_5_3 = db.create_task(
        "Validate security rules with emulator".to_string(),
        Some("Write and run security rule tests at backend/firestore.test.rules.ts to ensure proper access control".to_string()),
        Priority::High,
        Some(phase1.id.clone()),
    )?;

    let task_1_5_4 = db.create_task(
        "Create backend deployment checklist".to_string(),
        Some("Document and verify: All functions deployed, rules active, indexes created, API keys configured, monitoring enabled".to_string()),
        Priority::Medium,
        Some(phase1.id.clone()),
    )?;

    println!("✓ Created {} Phase 1 tasks", 14);

    // Phase 2: Implement Firebase Services (Week 2)
    let phase2 = db.create_task(
        "Phase 2: Implement Firebase Services (Week 2)".to_string(),
        Some("Implement FirebaseDataService, FirebaseStorageService, activate FirebaseAuthService, update AIServiceFactory".to_string()),
        Priority::Critical,
        Some(parent.id.clone()),
    )?;
    println!("✓ Created Phase 2: {}", phase2.id);

    // Phase 2.1: FirebaseDataService Implementation
    let task_2_1_2 = db.create_task(
        "Create FirebaseDataService base structure".to_string(),
        Some("Create class with Firestore initialization and user authentication handling. Conforms to DataServiceProtocol.".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_1_3 = db.create_task(
        "Implement Hero database operations".to_string(),
        Some("Complete saveHero, fetchHeroes, deleteHero with proper Firestore integration, data mapping, UUID/String conversions".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_1_4 = db.create_task(
        "Implement Story database operations".to_string(),
        Some("Complete saveStory, fetchStories, fetchStoriesForHero with reference handling and nested event data".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_1_5 = db.create_task(
        "Add Firestore model extensions".to_string(),
        Some("Extend Hero, Story models with toFirestoreData() and fromFirestoreData() for proper serialization".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    // Phase 2.2: FirebaseStorageService Implementation
    let task_2_2_2 = db.create_task(
        "Create FirebaseStorageService structure".to_string(),
        Some("Create class with Firebase Storage initialization and auth setup. Conforms to StorageServiceProtocol.".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_2_3 = db.create_task(
        "Implement avatar storage operations".to_string(),
        Some("Complete uploadAvatar, downloadAvatar, deleteAvatar with proper path formatting and metadata handling".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    let task_2_2_4 = db.create_task(
        "Implement audio storage operations".to_string(),
        Some("Complete uploadStoryAudio, downloadStoryAudio, deleteStoryAudio with MP3 handling and 50MB size limit".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    let task_2_2_5 = db.create_task(
        "Implement illustration storage operations".to_string(),
        Some("Complete scene illustration upload/download/delete with proper scene numbering and batch operations".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    // Phase 2.3: Activate FirebaseAuthService
    let task_2_3_1 = db.create_task(
        "Move FirebaseAuthService to active location".to_string(),
        Some("Relocate from Firebase-Pending to Services/ and update import paths. Preserve git history.".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_3_3 = db.create_task(
        "Integrate AuthViewModel with FirebaseAuthService".to_string(),
        Some("Update/create AuthViewModel using FirebaseAuthService, handle auth state changes, session persistence".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_3_4 = db.create_task(
        "Move and integrate FirebaseAuthView".to_string(),
        Some("Move FirebaseAuthView to Views/Auth/ and integrate with app navigation flow and AuthViewModel".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    let task_2_3_5 = db.create_task(
        "Implement auth state observer".to_string(),
        Some("Add Firebase Auth state listener for session changes, automatic sign-in, session expiry, offline mode".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    // Phase 2.4: Update AIServiceFactory
    let task_2_4_1 = db.create_task(
        "Remove Supabase feature flag".to_string(),
        Some(
            "Update AIServiceFactory to always return Firebase services, remove conditional logic"
                .to_string(),
        ),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_4_2 = db.create_task(
        "Add service getter methods".to_string(),
        Some("Implement static getters for dataService, storageService, authService with lazy initialization".to_string()),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    let task_2_4_3 = db.create_task(
        "Update ViewModels to use service getters".to_string(),
        Some("Refactor HeroViewModel, StoryViewModel to use AIServiceFactory getters, apply dependency injection pattern".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    // Phase 2.5: Integration Testing
    let task_2_5_1 = db.create_task(
        "Test Hero CRUD operations".to_string(),
        Some("Manually test create/read/update/delete heroes, avatar upload/display through app with Firebase backend".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    let task_2_5_2 = db.create_task(
        "Test Story operations".to_string(),
        Some("Test complete story generation flow: generate story, audio synthesis, illustration generation, playback".to_string()),
        Priority::High,
        Some(phase2.id.clone()),
    )?;

    let task_2_5_3 = db.create_task(
        "Test authentication flow".to_string(),
        Some(
            "Test sign up, sign in, sign out, session persistence, auth error handling end-to-end"
                .to_string(),
        ),
        Priority::Critical,
        Some(phase2.id.clone()),
    )?;

    println!("✓ Created {} Phase 2 tasks", 17);

    // Phase 3: Model Updates & Data Migration (Week 3)
    let phase3 = db.create_task(
        "Phase 3: Model Updates & Data Migration (Week 3)".to_string(),
        Some("Update model Codable implementations for Firestore, create data migration scripts if production data exists".to_string()),
        Priority::Critical,
        Some(parent.id.clone()),
    )?;
    println!("✓ Created Phase 3: {}", phase3.id);

    // Phase 3.1: Update Model Codable Implementations
    let task_3_1_1 = db.create_task(
        "Update Hero model for Firestore".to_string(),
        Some("Add toFirestoreData() and fromFirestoreData(), handle UUID↔String, Date↔Timestamp conversions. File: Models/Hero.swift".to_string()),
        Priority::Critical,
        Some(phase3.id.clone()),
    )?;

    let task_3_1_2 = db.create_task(
        "Update Story model for Firestore".to_string(),
        Some("Add Firestore conversion methods, handle nested event data, reference fields. File: Models/Story.swift".to_string()),
        Priority::Critical,
        Some(phase3.id.clone()),
    )?;

    let task_3_1_3 = db.create_task(
        "Update CustomStoryEvent model".to_string(),
        Some("Add Firestore serialization with proper field mapping. File: Models/CustomStoryEvent.swift".to_string()),
        Priority::High,
        Some(phase3.id.clone()),
    )?;

    let task_3_1_4 = db.create_task(
        "Update StoryIllustration model".to_string(),
        Some("Add Firestore compatibility for illustration metadata. File: Models/StoryIllustration.swift".to_string()),
        Priority::High,
        Some(phase3.id.clone()),
    )?;

    let task_3_1_5 = db.create_task(
        "Test model serialization".to_string(),
        Some(
            "Write unit tests for all model conversions, verify round-trip serialization integrity"
                .to_string(),
        ),
        Priority::High,
        Some(phase3.id.clone()),
    )?;

    // Phase 3.2: Data Migration (if production data exists)
    let task_3_2_1 = db.create_task(
        "Create data migration script".to_string(),
        Some("Write backend/scripts/migrate-data.ts to migrate heroes, stories from Supabase to Firestore".to_string()),
        Priority::High,
        Some(phase3.id.clone()),
    )?;

    let task_3_2_2 = db.create_task(
        "Implement storage migration".to_string(),
        Some("Add storage file migration (avatars, audio, illustrations) from Supabase Storage to Firebase Storage".to_string()),
        Priority::High,
        Some(phase3.id.clone()),
    )?;

    let task_3_2_3 = db.create_task(
        "Test migration on staging data".to_string(),
        Some(
            "Dry-run migration script with test data, verify data integrity and completeness"
                .to_string(),
        ),
        Priority::High,
        Some(phase3.id.clone()),
    )?;

    let task_3_2_4 = db.create_task(
        "Create data validation scripts".to_string(),
        Some("Write scripts to compare record counts, verify sample data between Supabase and Firestore".to_string()),
        Priority::Medium,
        Some(phase3.id.clone()),
    )?;

    let task_3_2_5 = db.create_task(
        "Document rollback procedure".to_string(),
        Some("Create detailed rollback plan for data migration if issues occur during production migration".to_string()),
        Priority::Medium,
        Some(phase3.id.clone()),
    )?;

    println!("✓ Created {} Phase 3 tasks", 10);

    // Phase 4: iOS Integration (Week 4)
    let phase4 = db.create_task(
        "Phase 4: iOS Integration (Week 4)".to_string(),
        Some("Update ViewModels and Views, modify app initialization, remove Supabase dependencies and files".to_string()),
        Priority::Critical,
        Some(parent.id.clone()),
    )?;
    println!("✓ Created Phase 4: {}", phase4.id);

    // Phase 4.1: Update ViewModels
    let task_4_1_1 = db.create_task(
        "Update HeroViewModel".to_string(),
        Some("Replace SupabaseService with AIServiceFactory.dataService and .storageService for all hero operations".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    let task_4_1_2 = db.create_task(
        "Update StoryViewModel".to_string(),
        Some("Replace SupabaseService with Firebase services for all story operations including generation and media".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    let task_4_1_3 = db.create_task(
        "Update other ViewModels".to_string(),
        Some("Update any remaining ViewModels using SupabaseService to use Firebase services via AIServiceFactory".to_string()),
        Priority::High,
        Some(phase4.id.clone()),
    )?;

    let task_4_1_4 = db.create_task(
        "Test ViewModel integration".to_string(),
        Some("Write unit tests for updated ViewModels, verify they work correctly with Firebase services".to_string()),
        Priority::High,
        Some(phase4.id.clone()),
    )?;

    // Phase 4.2: Update Views
    let task_4_2_1 = db.create_task(
        "Remove Supabase imports from Views".to_string(),
        Some("Search and remove all 'import Supabase' statements. Update any direct SupabaseService usage.".to_string()),
        Priority::High,
        Some(phase4.id.clone()),
    )?;

    let task_4_2_2 = db.create_task(
        "Test UI functionality".to_string(),
        Some("Manual testing of all views to ensure they work with updated ViewModels and Firebase backend".to_string()),
        Priority::High,
        Some(phase4.id.clone()),
    )?;

    // Phase 4.3: App Initialization
    let task_4_3_1 = db.create_task(
        "Update InfiniteStoriesApp.swift".to_string(),
        Some("Add AuthViewModel, configure Firestore settings, implement auth-based navigation between AuthView and ContentView".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    let task_4_3_2 = db.create_task(
        "Test app startup flow".to_string(),
        Some("Verify Firebase initialization, authentication state detection, proper view routing on app launch".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    // Phase 4.4: Remove Supabase Dependencies
    let task_4_4_1 = db.create_task(
        "Remove Supabase packages from Xcode".to_string(),
        Some("Open project in Xcode, go to Package Dependencies, remove supabase-swift and related packages".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    let task_4_4_2 = db.create_task(
        "Verify Package.resolved clean".to_string(),
        Some("Check project.xcworkspace/xcshareddata/swiftpm/Package.resolved contains no Supabase packages".to_string()),
        Priority::High,
        Some(phase4.id.clone()),
    )?;

    // Phase 4.5: Delete Supabase Files
    let task_4_5_1 = db.create_task(
        "Delete Supabase source files".to_string(),
        Some("Remove: SupabaseService.swift, SupabaseAIService.swift, SupabaseConfig.swift, SupabaseHelpers.swift".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    let task_4_5_2 = db.create_task(
        "Verify no Supabase references remain".to_string(),
        Some("Run: grep -r 'import Supabase' InfiniteStories/ - should return no results. Verify build succeeds.".to_string()),
        Priority::Critical,
        Some(phase4.id.clone()),
    )?;

    println!("✓ Created {} Phase 4 tasks", 12);

    // Phase 5: Testing & Validation (Week 5)
    let phase5 = db.create_task(
        "Phase 5: Testing & Validation (Week 5)".to_string(),
        Some("Comprehensive testing: unit tests, integration tests, performance tests, security validation, UAT".to_string()),
        Priority::Critical,
        Some(parent.id.clone()),
    )?;
    println!("✓ Created Phase 5: {}", phase5.id);

    // Create summary tasks for Phase 5 (details omitted for brevity but would include all 24 tasks)
    db.create_task(
        "Create Firebase service test infrastructure".to_string(),
        Some("Set up test harness with Firebase emulators, mock data generators, test utilities for all services".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Implement FirebaseDataService unit tests".to_string(),
        Some("Write comprehensive tests for all CRUD operations, error handling, data validation. Target >80% coverage.".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Implement FirebaseStorageService unit tests".to_string(),
        Some("Test avatar, audio, illustration upload/download/delete. Include file size validation and errors.".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Implement FirebaseAuthService unit tests".to_string(),
        Some("Test authentication flows: sign up, sign in, sign out, password reset, session management".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Design end-to-end test scenarios".to_string(),
        Some("Document comprehensive test scenarios for hero creation, story generation, auth flows, offline functionality".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Implement Hero-to-Story E2E test".to_string(),
        Some("Automated test: create hero → upload avatar → generate story → generate audio → generate illustrations".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Set up performance monitoring".to_string(),
        Some("Configure Firebase Performance SDK, Xcode Instruments, custom analytics events for benchmarking".to_string()),
        Priority::High,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Benchmark data operations".to_string(),
        Some("Measure Firestore query performance: fetchHeroes <500ms, fetchStories <500ms. Optimize as needed.".to_string()),
        Priority::High,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Write Firestore security rules tests".to_string(),
        Some("Implement automated tests for all Firestore security rules using Firebase rules unit testing framework".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Test Storage security rules".to_string(),
        Some("Validate storage bucket permissions, file size limits, content type restrictions for all buckets".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Prepare UAT test plan".to_string(),
        Some("Create comprehensive checklist: hero management, story generation, authentication, data persistence".to_string()),
        Priority::High,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Execute UAT test scenarios".to_string(),
        Some(
            "Manual testing of all user-facing features on physical iOS devices. Collect feedback."
                .to_string(),
        ),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    db.create_task(
        "Fix critical issues from UAT".to_string(),
        Some("Address blocking bugs and critical issues identified during user acceptance testing before deployment".to_string()),
        Priority::Critical,
        Some(phase5.id.clone()),
    )?;

    println!("✓ Created Phase 5 testing tasks");

    // Phase 6: Production Deployment (Week 6)
    let phase6 = db.create_task(
        "Phase 6: Production Deployment (Week 6)".to_string(),
        Some("Pre-deployment prep, backend deployment, iOS deployment, phased rollout, monitoring and response".to_string()),
        Priority::Critical,
        Some(parent.id.clone()),
    )?;
    println!("✓ Created Phase 6: {}", phase6.id);

    // Create summary tasks for Phase 6
    db.create_task(
        "Complete pre-deployment checklist".to_string(),
        Some("Verify: functions deployed, rules active, indexes created, secrets configured, monitoring enabled".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Configure production monitoring".to_string(),
        Some("Set up Firebase cost alerts, performance monitoring, error reporting, custom dashboards".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Update iOS app metadata".to_string(),
        Some("Bump version to 2.0.0, increment build number, update GoogleService-Info.plist for production".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Deploy Firestore rules and indexes".to_string(),
        Some(
            "Deploy production Firestore security rules and composite indexes. Verify deployment."
                .to_string(),
        ),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Deploy Storage rules".to_string(),
        Some("Deploy Firebase Storage security rules for all buckets to production".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Deploy Cloud Functions".to_string(),
        Some("Deploy all Cloud Functions to production with proper environment variables and secrets".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Build iOS release archive".to_string(),
        Some("Create production build with Release configuration, generate archive for App Store submission".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Submit to App Store Connect".to_string(),
        Some(
            "Upload archive to App Store Connect, complete metadata, submit for review".to_string(),
        ),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Execute phased rollout to 10%".to_string(),
        Some("Release to 10% of users on Day 4, monitor crash rates, API errors, performance metrics".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Expand rollout to 50%".to_string(),
        Some("Increase to 50% of users on Day 6 after validating 25% rollout success".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Complete full rollout to 100%".to_string(),
        Some(
            "Release to 100% of users after successful gradual rollout. All metrics must be green."
                .to_string(),
        ),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Implement rollback procedures".to_string(),
        Some("Document and test rollback process for both iOS app and backend services. Be ready to execute.".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Monitor critical metrics (7 days)".to_string(),
        Some("Daily checks: Crashlytics, function logs, performance metrics, costs, user feedback, support tickets".to_string()),
        Priority::Critical,
        Some(phase6.id.clone()),
    )?;

    db.create_task(
        "Prepare post-mortem report".to_string(),
        Some("Document deployment process, issues encountered, lessons learned, improvements for future migrations".to_string()),
        Priority::Medium,
        Some(phase6.id.clone()),
    )?;

    println!("✓ Created Phase 6 deployment tasks");

    // Summary
    let stats = db.get_stats()?;
    println!("\n📊 Migration Task Summary:");
    println!("   Total tasks created: {}", stats.total);
    println!("   Pending: {}", stats.pending);
    println!("   In Progress: {}", stats.in_progress);
    println!("   Completed: {}", stats.completed);

    println!("\n✅ All migration tasks populated successfully!");
    println!("📝 View tasks: cd tools/prd && ./target/release/prd list");
    println!("📊 View dashboard: ./target/release/prd-dashboard");

    Ok(())
}
