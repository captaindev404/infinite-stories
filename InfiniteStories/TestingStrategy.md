# Comprehensive Testing Strategy for SupabaseService Implementation

## Executive Summary

This document outlines a comprehensive testing strategy for the InfiniteStories iOS app's SupabaseService implementation, covering all 8 major TODO items with specific approaches for unit testing, integration testing, performance testing, and multi-device synchronization scenarios.

## 1. Testing Architecture Overview

### Test Pyramid Structure
```
         E2E Tests (10%)
        /            \
    Integration (30%)  \
   /                    \
  Unit Tests (60%)       \
 /________________________\
```

### Testing Frameworks & Tools

#### iOS Testing Stack
- **XCTest**: Core testing framework for unit and integration tests
- **Swift Testing**: Modern testing framework with async/await support
- **XCTestExpectation**: For async operations and network calls
- **OSLog**: For structured test logging and debugging
- **XCUITest**: UI automation for sync functionality

#### Backend Testing Tools
- **Supabase CLI**: Local Supabase instance for integration testing
- **Docker**: Containerized test environments
- **Postman/Newman**: API contract testing
- **K6**: Load and performance testing

## 2. Test Strategy for Each TODO Implementation

### TODO 1: Database Upsert Operations (Hero, Story models)

#### Unit Tests
```swift
class HeroUpsertTests: XCTestCase {
    var sut: SupabaseService!
    var mockClient: MockSupabaseClient!

    override func setUp() {
        super.setUp()
        mockClient = MockSupabaseClient()
        sut = SupabaseService(client: mockClient)
    }

    func testHeroUpsert_WithValidData_SavesSuccessfully() async throws {
        // Arrange
        let hero = Hero(name: "Test Hero",
                       primaryTrait: .brave,
                       secondaryTrait: .kind)
        mockClient.mockResponse = .success

        // Act
        try await sut.upsertHero(hero)

        // Assert
        XCTAssertTrue(hero.isSynced)
        XCTAssertNotNil(hero.lastSyncedAt)
        XCTAssertEqual(mockClient.lastUpsertData["name"] as? String, "Test Hero")
    }

    func testHeroUpsert_WithConflict_ResolvesCorrectly() async throws {
        // Test conflict resolution logic
    }

    func testStoryUpsert_WithLargeContent_CompressesData() async throws {
        // Test data compression for large stories
    }
}
```

#### Integration Tests
```swift
class HeroUpsertIntegrationTests: XCTestCase {
    var sut: SupabaseService!
    var testDatabase: TestSupabaseInstance!

    override func setUpWithError() throws {
        testDatabase = try TestSupabaseInstance.start()
        sut = SupabaseService(url: testDatabase.url,
                             key: testDatabase.serviceKey)
    }

    func testHeroUpsert_RealDatabase_PersistsCorrectly() async throws {
        // Test with actual local Supabase instance
        let hero = createTestHero()
        try await sut.upsertHero(hero)

        // Verify in database
        let fetched = try await testDatabase.query("SELECT * FROM heroes WHERE id = $1", hero.id)
        XCTAssertEqual(fetched.first?["name"], hero.name)
    }
}
```

### TODO 2: Database Fetch Operations with Filtering

#### Test Cases
```swift
class FetchOperationsTests: XCTestCase {

    func testFetchHeroes_WithPagination_ReturnsCorrectPage() async throws {
        // Arrange
        let pageSize = 10
        let pageNumber = 2

        // Act
        let heroes = try await sut.fetchHeroes(
            page: pageNumber,
            pageSize: pageSize,
            filters: nil
        )

        // Assert
        XCTAssertLesssThanOrEqual(heroes.count, pageSize)
        XCTAssertTrue(heroes.allSatisfy { $0.isActive })
    }

    func testFetchStories_WithComplexFilters_AppliesAllConditions() async throws {
        let filters = StoryFilters(
            heroId: UUID(),
            dateRange: Date()...Date(),
            isFavorite: true,
            eventType: .custom,
            language: "en"
        )

        let stories = try await sut.fetchStories(filters: filters)

        // Verify all filters applied
        stories.forEach { story in
            XCTAssertEqual(story.heroId, filters.heroId)
            XCTAssertTrue(story.isFavorite)
            XCTAssertEqual(story.eventType, .custom)
        }
    }
}
```

### TODO 3: Edge Function Calls

#### Mock Strategy for Edge Functions
```swift
protocol EdgeFunctionProtocol {
    func invoke<T: Decodable>(_ function: String,
                              payload: [String: Any]) async throws -> T
}

class MockEdgeFunctionClient: EdgeFunctionProtocol {
    var responses: [String: Any] = [:]
    var callCount: [String: Int] = [:]

    func invoke<T>(_ function: String, payload: [String: Any]) async throws -> T {
        callCount[function, default: 0] += 1

        guard let response = responses[function] else {
            throw EdgeFunctionError.notFound
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        return try JSONDecoder().decode(T.self, from: response)
    }
}
```

#### Edge Function Integration Tests
```swift
class EdgeFunctionTests: XCTestCase {

    func testStoryGeneration_WithValidHero_ReturnsStory() async throws {
        // Arrange
        let hero = createTestHero()
        let event = StoryEvent.bedtime

        // Act
        let result = try await sut.generateStory(
            heroId: hero.id.uuidString,
            event: event.toDictionary(),
            targetDuration: 300,
            language: "en"
        )

        // Assert
        XCTAssertFalse(result.content.isEmpty)
        XCTAssertGreaterThan(result.wordCount, 100)
        XCTAssertEqual(result.estimatedDuration, 300, accuracy: 30)
    }

    func testAudioSynthesis_WithLongText_ChunksCorrectly() async throws {
        let longText = String(repeating: "Test sentence. ", count: 500)

        let result = try await sut.synthesizeAudio(
            text: longText,
            voice: "nova",
            language: "en"
        )

        XCTAssertNotNil(result.audioUrl)
        XCTAssertGreaterThan(result.duration, 0)
    }

    func testSceneIllustration_WithMultipleScenes_GeneratesAll() async throws {
        let scenes = (1...5).map { createTestScene(number: $0) }

        let result = try await sut.generateSceneIllustrations(
            storyId: UUID().uuidString,
            scenes: scenes.map { $0.toDictionary() },
            heroVisualProfile: nil
        )

        XCTAssertEqual(result.illustrations.count, 5)
        XCTAssertTrue(result.failures?.isEmpty ?? true)
    }
}
```

### TODO 4: Real-time Subscriptions for Multi-device Sync

#### Real-time Subscription Tests
```swift
class RealtimeSubscriptionTests: XCTestCase {
    var sut: SupabaseService!
    var device1: SupabaseService!
    var device2: SupabaseService!

    func testRealtimeSync_HeroUpdate_PropagatesAcrossDevices() async throws {
        // Setup subscriptions
        let expectation = XCTestExpectation(description: "Sync received")

        device2.setupRealtimeSync()
        device2.onHeroUpdate = { hero in
            XCTAssertEqual(hero.name, "Updated Name")
            expectation.fulfill()
        }

        // Make change on device 1
        let hero = createTestHero()
        hero.name = "Updated Name"
        try await device1.upsertHero(hero)

        // Verify sync on device 2
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testRealtimeSync_ConflictResolution_LastWriteWins() async throws {
        // Test simultaneous updates from multiple devices
        let hero = createTestHero()

        // Both devices update simultaneously
        async let update1 = device1.updateHero(hero, name: "Device 1")
        async let update2 = device2.updateHero(hero, name: "Device 2")

        let results = try await (update1, update2)

        // Verify last write wins
        let finalHero = try await sut.fetchHero(id: hero.id)
        XCTAssertTrue(finalHero.name == "Device 1" || finalHero.name == "Device 2")
    }
}
```

### TODO 5: Configuration Management (Local vs Production)

#### Environment Configuration Tests
```swift
class ConfigurationTests: XCTestCase {

    func testLocalConfiguration_UsesCorrectEndpoints() {
        // Arrange
        setenv("SUPABASE_ENV", "local", 1)
        let config = SupabaseConfiguration.current

        // Assert
        XCTAssertEqual(config.url, URL(string: "http://127.0.0.1:54321"))
        XCTAssertTrue(config.key.hasPrefix("sb_"))
        XCTAssertTrue(config.isLocalDevelopment)
    }

    func testProductionConfiguration_UsesSecureEndpoints() {
        // Arrange
        setenv("SUPABASE_ENV", "production", 1)
        let config = SupabaseConfiguration.current

        // Assert
        XCTAssertTrue(config.url.absoluteString.hasPrefix("https://"))
        XCTAssertFalse(config.isLocalDevelopment)
        XCTAssertNotNil(KeychainHelper.shared.getAPIKey())
    }

    func testConfigurationSwitch_MigratesActiveConnections() async throws {
        // Test switching between environments maintains data integrity
    }
}
```

### TODO 6: Authentication and Authorization

#### Auth Tests
```swift
class AuthenticationTests: XCTestCase {

    func testAuthentication_WithValidCredentials_ReturnsSession() async throws {
        let session = try await sut.signIn(
            email: "test@example.com",
            password: "testpass123"
        )

        XCTAssertNotNil(session.accessToken)
        XCTAssertNotNil(session.user.id)
        XCTAssertGreaterThan(session.expiresIn, 0)
    }

    func testAuthorization_WithoutAuth_ThrowsUnauthorized() async throws {
        sut.clearSession()

        do {
            _ = try await sut.fetchHeroes()
            XCTFail("Should throw unauthorized error")
        } catch let error as SupabaseError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func testTokenRefresh_WhenExpired_RefreshesAutomatically() async throws {
        // Simulate expired token
        sut.mockExpiredToken()

        // Should refresh automatically
        let heroes = try await sut.fetchHeroes()

        XCTAssertFalse(heroes.isEmpty)
        XCTAssertTrue(sut.hasValidSession)
    }
}
```

### TODO 7: Error Handling and Retry Logic

#### Error Handling Tests
```swift
class ErrorHandlingTests: XCTestCase {

    func testRetryLogic_OnTransientFailure_RetriesSuccessfully() async throws {
        // Configure mock to fail twice then succeed
        mockClient.configureResponses([
            .failure(.networkError),
            .failure(.networkError),
            .success(testHero)
        ])

        let hero = try await sut.fetchHeroWithRetry(id: UUID())

        XCTAssertNotNil(hero)
        XCTAssertEqual(mockClient.callCount, 3)
    }

    func testExponentialBackoff_BetweenRetries_IncreasesDelay() async throws {
        let startTime = Date()
        mockClient.alwaysFail = true

        do {
            _ = try await sut.fetchHeroWithRetry(
                id: UUID(),
                maxRetries: 3
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            // 100ms + 200ms + 400ms = 700ms minimum
            XCTAssertGreaterThan(duration, 0.7)
        }
    }

    func testErrorMapping_SupabaseToUserFriendly_MapsCorrectly() {
        let errors: [(SupabaseError, String)] = [
            (.networkError, "Please check your internet connection"),
            (.unauthorized, "Please sign in to continue"),
            (.rateLimited, "Too many requests. Please wait."),
            (.serverError, "Something went wrong. Please try again.")
        ]

        errors.forEach { (error, expected) in
            XCTAssertEqual(error.userFriendlyMessage, expected)
        }
    }
}
```

### TODO 8: Network Connectivity Handling

#### Network Tests
```swift
class NetworkConnectivityTests: XCTestCase {
    var networkMonitor: NetworkMonitor!

    func testOfflineMode_QueuesOperations_SyncsWhenOnline() async throws {
        // Go offline
        networkMonitor.simulateOffline()

        // Queue operations
        let hero = createTestHero()
        try await sut.upsertHero(hero) // Should queue

        XCTAssertTrue(sut.hasPendingSync)
        XCTAssertEqual(sut.pendingOperations.count, 1)

        // Go online
        networkMonitor.simulateOnline()

        // Wait for sync
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertFalse(sut.hasPendingSync)
        XCTAssertEqual(sut.pendingOperations.count, 0)
    }

    func testNetworkChange_FromWiFiToCellular_ContinuesSync() async throws {
        networkMonitor.simulateNetworkChange(from: .wifi, to: .cellular)

        // Verify sync continues without interruption
        let heroes = try await sut.fetchHeroes()
        XCTAssertFalse(heroes.isEmpty)
    }
}
```

## 3. Integration Testing Approach with Supabase

### Local Supabase Test Environment

#### Setup Script
```bash
#!/bin/bash
# test-setup.sh

echo "Setting up test environment..."

# Start local Supabase
npx supabase start

# Wait for services
sleep 5

# Run migrations
npx supabase db reset

# Seed test data
psql $DATABASE_URL < test/fixtures/seed.sql

# Start Edge Functions
npx supabase functions serve &

echo "Test environment ready!"
```

#### Test Data Factory
```swift
class TestDataFactory {
    let supabase: SupabaseClient

    func createTestUser() async throws -> AuthUser {
        return try await supabase.auth.signUp(
            email: "test-\(UUID())@example.com",
            password: "TestPass123!"
        )
    }

    func createTestHero(for user: AuthUser) async throws -> Hero {
        let hero = Hero(
            name: "Test Hero \(Int.random(in: 1...1000))",
            primaryTrait: .brave,
            secondaryTrait: .kind,
            userId: user.id
        )

        try await supabase.from("heroes").insert(hero).execute()
        return hero
    }

    func createTestStory(hero: Hero) async throws -> Story {
        // Create story with all relationships
    }
}
```

### Integration Test Suite
```swift
class SupabaseIntegrationTestSuite: XCTestCase {
    static var supabase: SupabaseClient!
    static var testUser: AuthUser!

    override class func setUp() {
        super.setUp()

        // Start test environment
        shell("./test-setup.sh")

        // Initialize client
        supabase = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: getTestServiceKey()
        )

        // Create test user
        testUser = try! await TestDataFactory().createTestUser()
    }

    override class func tearDown() {
        // Cleanup
        shell("npx supabase stop")
        super.tearDown()
    }
}
```

## 4. Mock Strategies for Offline Testing

### Mock Service Architecture
```swift
protocol SupabaseServiceProtocol {
    func fetchHeroes() async throws -> [HeroData]
    func upsertHero(_ hero: Hero) async throws
    func generateStory(heroId: String, event: [String: Any]) async throws -> StoryGenerationResult
}

class MockSupabaseService: SupabaseServiceProtocol {
    var mockData: MockDataStore
    var shouldFail: Bool = false
    var networkDelay: TimeInterval = 0.1

    func fetchHeroes() async throws -> [HeroData] {
        try await simulateNetwork()

        if shouldFail {
            throw SupabaseError.networkError
        }

        return mockData.heroes
    }

    private func simulateNetwork() async throws {
        try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
    }
}
```

### Offline Data Store
```swift
class OfflineDataStore {
    private let modelContext: ModelContext
    private var pendingSync: [SyncOperation] = []

    func save<T: SyncableModel>(_ model: T) {
        modelContext.insert(model)

        if !NetworkMonitor.shared.isConnected {
            pendingSync.append(SyncOperation(model: model, type: .upsert))
        }
    }

    func syncWhenOnline() {
        NetworkMonitor.shared.onConnectionRestored = { [weak self] in
            self?.processPendingSync()
        }
    }
}
```

## 5. Performance Testing for Sync Operations

### Performance Test Suite
```swift
class SyncPerformanceTests: XCTestCase {

    func testBulkHeroSync_1000Records_CompletesUnder5Seconds() throws {
        measure {
            let heroes = (1...1000).map { _ in createTestHero() }

            let expectation = XCTestExpectation()

            Task {
                try await sut.bulkUpsertHeroes(heroes)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testIncrementalSync_DetectsChangesEfficiently() throws {
        // Setup initial state
        let heroes = createTestHeroes(count: 100)
        try await sut.initialSync(heroes)

        // Modify 10%
        let modified = heroes.prefix(10).map { hero in
            hero.name += " Modified"
            return hero
        }

        measure {
            let syncStart = Date()
            try await sut.incrementalSync(modified)
            let syncDuration = Date().timeIntervalSince(syncStart)

            XCTAssertLessThan(syncDuration, 0.5) // Should be fast
        }
    }
}
```

### Load Testing with K6
```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '30s', target: 20 },  // Ramp up
        { duration: '1m', target: 20 },   // Stay at 20 users
        { duration: '30s', target: 100 }, // Spike to 100
        { duration: '1m', target: 100 },  // Stay at 100
        { duration: '30s', target: 0 },   // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
        http_req_failed: ['rate<0.1'],    // Error rate under 10%
    },
};

export default function() {
    // Test story generation under load
    let response = http.post(
        'http://localhost:54321/functions/v1/story-generation',
        JSON.stringify({
            heroId: 'test-hero-id',
            event: { type: 'bedtime' },
            targetDuration: 300,
        }),
        {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + __ENV.TEST_TOKEN,
            },
        }
    );

    check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 2s': (r) => r.timings.duration < 2000,
    });

    sleep(1);
}
```

## 6. Error Scenario Testing Patterns

### Comprehensive Error Scenarios
```swift
class ErrorScenarioTests: XCTestCase {

    func testNetworkTimeout_AfterRetries_ThrowsError() async throws {
        mockClient.simulateTimeout(duration: 30)

        do {
            _ = try await sut.fetchHeroes(timeout: 5)
            XCTFail("Should timeout")
        } catch let error as SupabaseError {
            XCTAssertEqual(error, .timeout)
        }
    }

    func testRateLimiting_Returns429_BacksOff() async throws {
        mockClient.simulateRateLimit(
            resetAfter: 60,
            requestsBeforeLimit: 5
        )

        // Make rapid requests
        for i in 0..<10 {
            do {
                _ = try await sut.generateStory(...)
            } catch let error as SupabaseError {
                if i >= 5 {
                    XCTAssertEqual(error, .rateLimited)
                }
            }
        }
    }

    func testPartialSync_OnFailure_RollsBack() async throws {
        let heroes = createTestHeroes(count: 10)
        mockClient.failAfterNRequests(5)

        do {
            try await sut.bulkUpsertHeroes(heroes)
            XCTFail("Should fail")
        } catch {
            // Verify rollback
            let synced = try await sut.fetchHeroes()
            XCTAssertEqual(synced.count, 0) // All rolled back
        }
    }
}
```

## 7. Multi-device Testing Procedures

### Device Simulation Framework
```swift
class MultiDeviceTestHarness {
    var devices: [String: SupabaseService] = [:]

    func addDevice(identifier: String) -> SupabaseService {
        let service = SupabaseService(deviceId: identifier)
        devices[identifier] = service
        return service
    }

    func simulateSimultaneousUpdates() async throws {
        let hero = createSharedHero()

        // All devices update at once
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (deviceId, service) in devices {
                group.addTask {
                    hero.name = "Updated by \(deviceId)"
                    try await service.upsertHero(hero)
                }
            }
        }

        // Verify consistency
        let finalStates = try await withTaskGroup(of: Hero?.self) { group in
            for service in devices.values {
                group.addTask {
                    try? await service.fetchHero(id: hero.id)
                }
            }

            var results: [Hero] = []
            for await hero in group {
                if let hero = hero {
                    results.append(hero)
                }
            }
            return results
        }

        // All devices should see the same final state
        let names = Set(finalStates.map { $0.name })
        XCTAssertEqual(names.count, 1, "Inconsistent state across devices")
    }
}
```

### UI Test for Multi-device Sync
```swift
class MultiDeviceSyncUITests: XCUITestCase {
    var app1: XCUIApplication!
    var app2: XCUIApplication!

    override func setUp() {
        super.setUp()

        app1 = XCUIApplication()
        app1.launchArguments = ["--device-id", "iPhone-1"]
        app1.launch()

        app2 = XCUIApplication()
        app2.launchArguments = ["--device-id", "iPad-1"]
        app2.launch()
    }

    func testCrossDeviceStorySync() {
        // Create story on device 1
        app1.buttons["Create Story"].tap()
        app1.textFields["Story Title"].typeText("Test Story")
        app1.buttons["Save"].tap()

        // Wait for sync
        sleep(2)

        // Verify on device 2
        app2.swipeDown() // Refresh

        let story = app2.cells["Test Story"]
        XCTAssertTrue(story.exists)
    }
}
```

## 8. Automated Testing Setup for CI/CD

### GitHub Actions Workflow
```yaml
name: iOS Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Supabase
      run: |
        npm install -g supabase
        npx supabase start
        npx supabase db reset

    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable

    - name: Install Dependencies
      run: |
        brew install swiftlint
        pod install --project-directory=InfiniteStories

    - name: Run Unit Tests
      run: |
        xcodebuild test \
          -workspace InfiniteStories.xcworkspace \
          -scheme InfiniteStories \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          -resultBundlePath TestResults

    - name: Run Integration Tests
      env:
        SUPABASE_URL: http://localhost:54321
        SUPABASE_KEY: ${{ secrets.TEST_SERVICE_KEY }}
      run: |
        xcodebuild test \
          -workspace InfiniteStories.xcworkspace \
          -scheme InfiniteStoriesIntegration \
          -destination 'platform=iOS Simulator,name=iPhone 15'

    - name: Run UI Tests
      run: |
        xcodebuild test \
          -workspace InfiniteStories.xcworkspace \
          -scheme InfiniteStoriesUITests \
          -destination 'platform=iOS Simulator,name=iPhone 15'

    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: TestResults.xcresult

    - name: Code Coverage
      run: |
        xcrun xccov view --report TestResults.xcresult
```

### Fastlane Configuration
```ruby
# Fastfile
platform :ios do
  desc "Run all tests"
  lane :test do
    run_tests(
      workspace: "InfiniteStories.xcworkspace",
      devices: ["iPhone 15", "iPad Pro (12.9-inch)"],
      ensure_devices_found: true,
      reset_simulator: true,
      parallel_testing: true,
      concurrent_workers: 4,
      code_coverage: true
    )
  end

  lane :integration_test do
    sh("npx supabase start")

    run_tests(
      workspace: "InfiniteStories.xcworkspace",
      scheme: "InfiniteStoriesIntegration",
      configuration: "Debug"
    )

    sh("npx supabase stop")
  end

  lane :performance_test do
    scan(
      workspace: "InfiniteStories.xcworkspace",
      scheme: "PerformanceTests",
      configuration: "Release"
    )
  end
end
```

## 9. Test Data Management

### Test Data Fixtures
```swift
struct TestFixtures {
    static let heroes = [
        Hero(name: "Luna", primaryTrait: .curious, secondaryTrait: .kind),
        Hero(name: "Max", primaryTrait: .brave, secondaryTrait: .funny),
        Hero(name: "Zara", primaryTrait: .creative, secondaryTrait: .clever)
    ]

    static let stories = [
        Story(title: "The Moonlight Adventure", content: "...", heroId: heroes[0].id),
        Story(title: "Dragon's Treasure", content: "...", heroId: heroes[1].id)
    ]

    static func loadJSON<T: Decodable>(_ filename: String) -> T {
        let url = Bundle(for: TestFixtures.self).url(forResource: filename, withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(T.self, from: data)
    }
}
```

### Database Seeding
```sql
-- test/fixtures/seed.sql
INSERT INTO heroes (id, user_id, name, primary_trait, secondary_trait)
VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'test-user-1', 'Test Hero 1', 'brave', 'kind'),
  ('550e8400-e29b-41d4-a716-446655440002', 'test-user-1', 'Test Hero 2', 'curious', 'funny');

INSERT INTO stories (id, hero_id, title, content)
VALUES
  ('660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'Test Story', 'Content...');
```

## 10. Monitoring and Reporting

### Test Metrics Dashboard
```swift
class TestMetrics {
    static func generateReport() -> TestReport {
        return TestReport(
            totalTests: getTotalTests(),
            passed: getPassedTests(),
            failed: getFailedTests(),
            coverage: getCodeCoverage(),
            performance: getPerformanceMetrics(),
            flakyTests: identifyFlakyTests()
        )
    }

    static func identifyFlakyTests() -> [String] {
        // Analyze test history for intermittent failures
        let history = TestHistoryAnalyzer()
        return history.findTestsWithInconsistentResults(threshold: 0.8)
    }
}
```

## 11. Best Practices and Guidelines

### Test Naming Convention
```swift
// Format: test_WhatIsBeingTested_Condition_ExpectedResult
func test_HeroCreation_WithValidData_SavesSuccessfully()
func test_StoryGeneration_WhenOffline_QueuesForLaterSync()
func test_Authentication_WithExpiredToken_RefreshesAutomatically()
```

### Async Testing Pattern
```swift
func testAsyncOperation() async throws {
    // Arrange
    let input = setupTestData()

    // Act
    let result = try await sut.performAsyncOperation(input)

    // Assert
    XCTAssertEqual(result, expectedValue)

    // Cleanup
    await cleanup()
}
```

### Test Isolation
```swift
class IsolatedTest: XCTestCase {
    override func setUp() {
        super.setUp()
        // Fresh instance for each test
        sut = SupabaseService(inMemory: true)
    }

    override func tearDown() {
        // Clean up all data
        sut.reset()
        super.tearDown()
    }
}
```

## 12. Continuous Improvement

### Test Coverage Goals
- **Unit Tests**: 80% minimum coverage
- **Integration Tests**: Cover all critical user paths
- **UI Tests**: Cover primary user journeys
- **Performance Tests**: All sync operations

### Monthly Review Checklist
- [ ] Review flaky tests and fix or remove
- [ ] Update test data to match production patterns
- [ ] Optimize slow tests
- [ ] Add tests for new features
- [ ] Review and update mocks
- [ ] Performance baseline updates

## Conclusion

This comprehensive testing strategy ensures robust validation of all SupabaseService implementations while maintaining fast feedback cycles and reliable test results. The combination of unit, integration, and E2E tests provides confidence in both individual components and the complete system behavior.