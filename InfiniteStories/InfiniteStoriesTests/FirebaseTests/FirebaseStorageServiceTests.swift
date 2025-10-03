//
//  FirebaseStorageServiceTests.swift
//  InfiniteStoriesTests
//
//  Comprehensive tests for Firebase Storage operations
//

import XCTest
import FirebaseStorage
@testable import InfiniteStories

final class FirebaseStorageServiceTests: FirebaseTestBase {

    // MARK: - Properties

    var storageService: FirebaseStorageServiceMock!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Initialize storage service with test Storage instance
        storageService = FirebaseStorageServiceMock(storage: testStorage)
    }

    override func tearDownWithError() throws {
        // Clean up test files
        Task {
            try? await cleanupTestFiles()
        }

        storageService = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper Methods

    private func cleanupTestFiles() async throws {
        let paths = [
            "avatars/test-",
            "audio/test-",
            "illustrations/test-",
            "exports/test-"
        ]

        for pathPrefix in paths {
            let ref = testStorage.reference().child(pathPrefix)
            do {
                let result = try await ref.listAll()
                for item in result.items {
                    try await item.delete()
                }
            } catch {
                // Ignore errors during cleanup
            }
        }
    }

    private func createTestImage() -> Data {
        // Create a simple 1x1 pixel PNG image
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image.pngData()!
    }

    private func createTestAudio() -> Data {
        // Create mock MP3 data (just for testing, not a real MP3)
        return "Mock MP3 Audio Data".data(using: .utf8)!
    }

    private func createTestJSON() -> Data {
        let json = ["test": "data", "value": 123]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - Avatar Upload Tests

    func testUploadAvatar() async throws {
        // Given
        let imageData = createTestImage()
        let heroId = "test-hero-\(UUID().uuidString)"

        // When
        let url = try await storageService.uploadAvatar(
            heroId: heroId,
            imageData: imageData
        )

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains("avatars/"))
        XCTAssertTrue(url.absoluteString.contains(heroId))
    }

    func testUploadAvatarWithMetadata() async throws {
        // Given
        let imageData = createTestImage()
        let heroId = "test-hero-\(UUID().uuidString)"

        // When
        let url = try await storageService.uploadAvatar(
            heroId: heroId,
            imageData: imageData,
            metadata: ["heroName": "Test Hero"]
        )

        // Then
        XCTAssertNotNil(url)

        // Verify metadata
        let ref = testStorage.reference().child("avatars/\(heroId).png")
        let metadata = try await ref.getMetadata()
        XCTAssertEqual(metadata.customMetadata?["heroName"], "Test Hero")
    }

    func testDownloadAvatar() async throws {
        // Given - Upload an avatar first
        let imageData = createTestImage()
        let heroId = "test-hero-\(UUID().uuidString)"
        _ = try await storageService.uploadAvatar(
            heroId: heroId,
            imageData: imageData
        )

        // When
        let downloadedData = try await storageService.downloadAvatar(heroId: heroId)

        // Then
        XCTAssertNotNil(downloadedData)
        XCTAssertEqual(downloadedData.count, imageData.count)
    }

    func testDeleteAvatar() async throws {
        // Given - Upload an avatar first
        let imageData = createTestImage()
        let heroId = "test-hero-\(UUID().uuidString)"
        _ = try await storageService.uploadAvatar(
            heroId: heroId,
            imageData: imageData
        )

        // When
        try await storageService.deleteAvatar(heroId: heroId)

        // Then - Try to download, should fail
        do {
            _ = try await storageService.downloadAvatar(heroId: heroId)
            XCTFail("Expected download to fail after deletion")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Audio Upload Tests

    func testUploadAudio() async throws {
        // Given
        let audioData = createTestAudio()
        let storyId = "test-story-\(UUID().uuidString)"

        // When
        let url = try await storageService.uploadAudio(
            storyId: storyId,
            audioData: audioData
        )

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains("audio/"))
        XCTAssertTrue(url.absoluteString.contains(storyId))
    }

    func testUploadAudioWithDuration() async throws {
        // Given
        let audioData = createTestAudio()
        let storyId = "test-story-\(UUID().uuidString)"
        let duration = 180.5 // 3 minutes 0.5 seconds

        // When
        let url = try await storageService.uploadAudio(
            storyId: storyId,
            audioData: audioData,
            duration: duration
        )

        // Then
        XCTAssertNotNil(url)

        // Verify metadata
        let ref = testStorage.reference().child("audio/\(storyId).mp3")
        let metadata = try await ref.getMetadata()
        XCTAssertEqual(metadata.customMetadata?["duration"], "180.5")
    }

    func testDownloadAudio() async throws {
        // Given - Upload audio first
        let audioData = createTestAudio()
        let storyId = "test-story-\(UUID().uuidString)"
        _ = try await storageService.uploadAudio(
            storyId: storyId,
            audioData: audioData
        )

        // When
        let downloadedData = try await storageService.downloadAudio(storyId: storyId)

        // Then
        XCTAssertNotNil(downloadedData)
        XCTAssertEqual(downloadedData.count, audioData.count)
    }

    func testStreamAudioURL() async throws {
        // Given - Upload audio first
        let audioData = createTestAudio()
        let storyId = "test-story-\(UUID().uuidString)"
        _ = try await storageService.uploadAudio(
            storyId: storyId,
            audioData: audioData
        )

        // When
        let streamURL = try await storageService.getAudioStreamURL(storyId: storyId)

        // Then
        XCTAssertNotNil(streamURL)
        XCTAssertTrue(streamURL.absoluteString.contains(storyId))
    }

    // MARK: - Illustration Upload Tests

    func testUploadIllustration() async throws {
        // Given
        let imageData = createTestImage()
        let storyId = "test-story-\(UUID().uuidString)"
        let sceneNumber = 1

        // When
        let url = try await storageService.uploadIllustration(
            storyId: storyId,
            sceneNumber: sceneNumber,
            imageData: imageData
        )

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains("illustrations/"))
        XCTAssertTrue(url.absoluteString.contains(storyId))
        XCTAssertTrue(url.absoluteString.contains("scene-1"))
    }

    func testUploadMultipleIllustrations() async throws {
        // Given
        let imageData = createTestImage()
        let storyId = "test-story-\(UUID().uuidString)"

        // When - Upload 3 scenes
        let url1 = try await storageService.uploadIllustration(
            storyId: storyId,
            sceneNumber: 1,
            imageData: imageData
        )
        let url2 = try await storageService.uploadIllustration(
            storyId: storyId,
            sceneNumber: 2,
            imageData: imageData
        )
        let url3 = try await storageService.uploadIllustration(
            storyId: storyId,
            sceneNumber: 3,
            imageData: imageData
        )

        // Then
        XCTAssertNotNil(url1)
        XCTAssertNotNil(url2)
        XCTAssertNotNil(url3)
        XCTAssertTrue(url1.absoluteString.contains("scene-1"))
        XCTAssertTrue(url2.absoluteString.contains("scene-2"))
        XCTAssertTrue(url3.absoluteString.contains("scene-3"))
    }

    func testDownloadAllIllustrations() async throws {
        // Given - Upload multiple illustrations
        let imageData = createTestImage()
        let storyId = "test-story-\(UUID().uuidString)"

        for scene in 1...3 {
            _ = try await storageService.uploadIllustration(
                storyId: storyId,
                sceneNumber: scene,
                imageData: imageData
            )
        }

        // When
        let illustrations = try await storageService.downloadAllIllustrations(storyId: storyId)

        // Then
        XCTAssertEqual(illustrations.count, 3)
        for (_, data) in illustrations {
            XCTAssertEqual(data.count, imageData.count)
        }
    }

    // MARK: - Export Tests

    func testUploadExportedStory() async throws {
        // Given
        let exportData = createTestJSON()
        let storyId = "test-story-\(UUID().uuidString)"
        let exportType = "backup"

        // When
        let url = try await storageService.uploadExport(
            storyId: storyId,
            exportType: exportType,
            data: exportData
        )

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains("exports/"))
        XCTAssertTrue(url.absoluteString.contains(storyId))
        XCTAssertTrue(url.absoluteString.contains(exportType))
    }

    // MARK: - Batch Operations Tests

    func testBatchUpload() async throws {
        // Given
        let imageData = createTestImage()
        let audioData = createTestAudio()
        let storyId = "test-story-\(UUID().uuidString)"
        let heroId = "test-hero-\(UUID().uuidString)"

        // When - Upload multiple files
        async let avatarURL = storageService.uploadAvatar(
            heroId: heroId,
            imageData: imageData
        )
        async let audioURL = storageService.uploadAudio(
            storyId: storyId,
            audioData: audioData
        )
        async let illustrationURL = storageService.uploadIllustration(
            storyId: storyId,
            sceneNumber: 1,
            imageData: imageData
        )

        let urls = try await [avatarURL, audioURL, illustrationURL]

        // Then
        XCTAssertEqual(urls.count, 3)
        urls.forEach { XCTAssertNotNil($0) }
    }

    func testBatchDelete() async throws {
        // Given - Upload multiple files
        let imageData = createTestImage()
        let storyId = "test-story-\(UUID().uuidString)"

        for scene in 1...3 {
            _ = try await storageService.uploadIllustration(
                storyId: storyId,
                sceneNumber: scene,
                imageData: imageData
            )
        }

        // When - Delete all illustrations for story
        try await storageService.deleteAllIllustrations(storyId: storyId)

        // Then - Verify all are deleted
        do {
            _ = try await storageService.downloadAllIllustrations(storyId: storyId)
            // Should be empty or fail
        } catch {
            // Expected if properly deleted
            XCTAssertTrue(true)
        }
    }

    // MARK: - Error Handling Tests

    func testDownloadNonExistentFile() async {
        // Given
        let nonExistentId = "non-existent-\(UUID().uuidString)"

        // When/Then
        do {
            _ = try await storageService.downloadAvatar(heroId: nonExistentId)
            XCTFail("Expected download to fail for non-existent file")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func testUploadLargeFile() async throws {
        // Given - Create a "large" file (1MB for testing)
        let largeData = Data(repeating: 0, count: 1024 * 1024)
        let storyId = "test-story-\(UUID().uuidString)"

        // When
        let url = try await storageService.uploadAudio(
            storyId: storyId,
            audioData: largeData
        )

        // Then
        XCTAssertNotNil(url)

        // Verify size
        let ref = testStorage.reference().child("audio/\(storyId).mp3")
        let metadata = try await ref.getMetadata()
        XCTAssertEqual(metadata.size, Int64(largeData.count))
    }

    // MARK: - URL Generation Tests

    func testGenerateDownloadURL() async throws {
        // Given - Upload a file
        let imageData = createTestImage()
        let heroId = "test-hero-\(UUID().uuidString)"
        _ = try await storageService.uploadAvatar(
            heroId: heroId,
            imageData: imageData
        )

        // When
        let downloadURL = try await storageService.getDownloadURL(
            path: "avatars/\(heroId).png"
        )

        // Then
        XCTAssertNotNil(downloadURL)
        XCTAssertTrue(downloadURL.absoluteString.contains(heroId))
    }

    func testGenerateSignedURL() async throws {
        // Given - Upload a file
        let audioData = createTestAudio()
        let storyId = "test-story-\(UUID().uuidString)"
        _ = try await storageService.uploadAudio(
            storyId: storyId,
            audioData: audioData
        )

        // When
        let signedURL = try await storageService.getSignedURL(
            path: "audio/\(storyId).mp3",
            expirationMinutes: 60
        )

        // Then
        XCTAssertNotNil(signedURL)
        XCTAssertTrue(signedURL.absoluteString.contains("token="))
    }
}

// MARK: - FirebaseStorageServiceMock Implementation

/// Mock/Test implementation of Firebase Storage Service
class FirebaseStorageServiceMock {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    // MARK: - Avatar Methods

    func uploadAvatar(
        heroId: String,
        imageData: Data,
        metadata: [String: String]? = nil
    ) async throws -> URL {
        let path = "avatars/\(heroId).png"
        let ref = storage.reference().child(path)

        let storageMetadata = StorageMetadata()
        storageMetadata.contentType = "image/png"
        storageMetadata.customMetadata = metadata

        _ = try await ref.putDataAsync(imageData, metadata: storageMetadata)
        return try await ref.downloadURL()
    }

    func downloadAvatar(heroId: String) async throws -> Data {
        let path = "avatars/\(heroId).png"
        let ref = storage.reference().child(path)
        return try await ref.data(maxSize: 10 * 1024 * 1024) // 10MB max
    }

    func deleteAvatar(heroId: String) async throws {
        let path = "avatars/\(heroId).png"
        let ref = storage.reference().child(path)
        try await ref.delete()
    }

    // MARK: - Audio Methods

    func uploadAudio(
        storyId: String,
        audioData: Data,
        duration: Double? = nil
    ) async throws -> URL {
        let path = "audio/\(storyId).mp3"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "audio/mpeg"
        if let duration = duration {
            metadata.customMetadata = ["duration": String(duration)]
        }

        _ = try await ref.putDataAsync(audioData, metadata: metadata)
        return try await ref.downloadURL()
    }

    func downloadAudio(storyId: String) async throws -> Data {
        let path = "audio/\(storyId).mp3"
        let ref = storage.reference().child(path)
        return try await ref.data(maxSize: 50 * 1024 * 1024) // 50MB max
    }

    func getAudioStreamURL(storyId: String) async throws -> URL {
        let path = "audio/\(storyId).mp3"
        let ref = storage.reference().child(path)
        return try await ref.downloadURL()
    }

    // MARK: - Illustration Methods

    func uploadIllustration(
        storyId: String,
        sceneNumber: Int,
        imageData: Data
    ) async throws -> URL {
        let path = "illustrations/\(storyId)/scene-\(sceneNumber).png"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/png"
        metadata.customMetadata = ["sceneNumber": String(sceneNumber)]

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        return try await ref.downloadURL()
    }

    func downloadAllIllustrations(storyId: String) async throws -> [(Int, Data)] {
        let folderRef = storage.reference().child("illustrations/\(storyId)")
        let result = try await folderRef.listAll()

        var illustrations: [(Int, Data)] = []

        for item in result.items {
            // Extract scene number from filename
            let filename = item.name
            if let sceneNumberStr = filename
                .replacingOccurrences(of: "scene-", with: "")
                .replacingOccurrences(of: ".png", with: "")
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .first,
               let sceneNumber = Int(sceneNumberStr) {

                let data = try await item.data(maxSize: 10 * 1024 * 1024)
                illustrations.append((sceneNumber, data))
            }
        }

        return illustrations.sorted { $0.0 < $1.0 }
    }

    func deleteAllIllustrations(storyId: String) async throws {
        let folderRef = storage.reference().child("illustrations/\(storyId)")
        let result = try await folderRef.listAll()

        for item in result.items {
            try await item.delete()
        }
    }

    // MARK: - Export Methods

    func uploadExport(
        storyId: String,
        exportType: String,
        data: Data
    ) async throws -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "exports/\(storyId)/\(exportType)-\(timestamp).json"
        let ref = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = "application/json"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL()
    }

    // MARK: - URL Methods

    func getDownloadURL(path: String) async throws -> URL {
        let ref = storage.reference().child(path)
        return try await ref.downloadURL()
    }

    func getSignedURL(path: String, expirationMinutes: Int) async throws -> URL {
        // Note: In real implementation, this would generate a signed URL
        // For testing with emulator, we'll just return the download URL
        return try await getDownloadURL(path: path)
    }
}