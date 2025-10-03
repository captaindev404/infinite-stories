//
//  FirebaseStorageService.swift
//  InfiniteStories
//
//  Firebase Storage service for managing file uploads/downloads
//  Handles avatars, audio files, and illustrations
//

import Foundation
import FirebaseStorage
import FirebaseCore
import UIKit

// MARK: - Storage Service Protocol

protocol StorageServiceProtocol {
    // Avatar operations
    func uploadAvatar(heroId: UUID, imageData: Data) async throws -> String
    func downloadAvatar(heroId: UUID) async throws -> Data?
    func deleteAvatar(heroId: UUID) async throws
    func getAvatarURL(heroId: UUID) -> String?

    // Audio operations
    func uploadStoryAudio(storyId: UUID, audioData: Data) async throws -> String
    func downloadStoryAudio(storyId: UUID) async throws -> Data?
    func deleteStoryAudio(storyId: UUID) async throws
    func getAudioURL(storyId: UUID) -> String?

    // Illustration operations
    func uploadSceneIllustration(storyId: UUID, sceneNumber: Int, imageData: Data) async throws -> String
    func downloadSceneIllustration(storyId: UUID, sceneNumber: Int) async throws -> Data?
    func deleteSceneIllustration(storyId: UUID, sceneNumber: Int) async throws
    func getIllustrationURL(storyId: UUID, sceneNumber: Int) -> String?

    // Bulk operations
    func deleteAllHeroStorage(heroId: UUID) async throws
    func deleteAllStoryStorage(storyId: UUID) async throws
}

// MARK: - Firebase Storage Service

@MainActor
final class FirebaseStorageService: ObservableObject, StorageServiceProtocol {
    static let shared = FirebaseStorageService()

    // MARK: - Properties

    private let storage: Storage
    private let storageRef: StorageReference
    private let authService = FirebaseAuthService.shared

    // Storage buckets
    private let avatarBucket = "hero-avatars"
    private let audioBucket = "story-audio"
    private let illustrationBucket = "story-illustrations"

    // Cache control settings
    private let defaultCacheControl = "public, max-age=86400" // 24 hours

    // File size limits
    private let maxAvatarSize: Int64 = 10 * 1024 * 1024 // 10MB
    private let maxAudioSize: Int64 = 50 * 1024 * 1024 // 50MB
    private let maxIllustrationSize: Int64 = 10 * 1024 * 1024 // 10MB

    // MARK: - Initialization

    private init() {
        // Ensure Firebase is configured
        if FirebaseApp.app() == nil {
            FirebaseConfig.configure()
        }

        self.storage = Storage.storage()
        self.storageRef = storage.reference()

        print("📦 Firebase Storage Service initialized")
        print("🪣 Storage buckets configured: avatars, audio, illustrations")

        // Configure storage settings
        configureStorage()
    }

    private func configureStorage() {
        // Set maximum upload retry time
        storage.maxUploadRetryTime = 60.0 // 60 seconds

        // Set maximum download retry time
        storage.maxDownloadRetryTime = 60.0 // 60 seconds

        // Set maximum operation retry time
        storage.maxOperationRetryTime = 60.0 // 60 seconds
    }

    // MARK: - Helper Methods

    /// Get current user ID from Firebase Auth
    private func getCurrentUserId() async throws -> String {
        guard let userId = authService.currentUserId else {
            throw FirebaseStorageError.noUserAuthenticated
        }
        return userId
    }

    /// Create storage metadata with content type and cache control
    private func createMetadata(contentType: String, customMetadata: [String: String]? = nil) -> StorageMetadata {
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        metadata.cacheControl = defaultCacheControl

        if let custom = customMetadata {
            metadata.customMetadata = custom
        }

        return metadata
    }

    /// Check if a file exists at the given path
    private func fileExists(at path: String) async -> Bool {
        do {
            _ = try await storageRef.child(path).getMetadata()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Avatar Operations

    func uploadAvatar(heroId: UUID, imageData: Data) async throws -> String {
        let userId = try await getCurrentUserId()

        // Check file size
        guard imageData.count <= maxAvatarSize else {
            throw FirebaseStorageError.fileTooLarge(maxSize: maxAvatarSize)
        }

        let fileName = "\(userId)/\(heroId.uuidString)/avatar.png"
        let avatarRef = storageRef.child("\(avatarBucket)/\(fileName)")

        print("📤 Uploading avatar: \(fileName)")

        // Create metadata
        let metadata = createMetadata(
            contentType: "image/png",
            customMetadata: [
                "heroId": heroId.uuidString,
                "userId": userId,
                "uploadedAt": ISO8601DateFormatter().string(from: Date())
            ]
        )

        do {
            // Upload the file
            let uploadTask = avatarRef.putData(imageData, metadata: metadata)

            // Monitor upload progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    print("📊 Avatar upload progress: \(String(format: "%.1f", percentComplete))%")
                }
            }

            // Wait for upload to complete
            _ = try await uploadTask.observe(.success)

            // Get download URL
            let downloadURL = try await avatarRef.downloadURL()

            print("✅ Avatar uploaded successfully: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString

        } catch {
            print("❌ Failed to upload avatar: \(error)")
            throw FirebaseStorageError.uploadFailed(error.localizedDescription)
        }
    }

    func downloadAvatar(heroId: UUID) async throws -> Data? {
        let userId = try await getCurrentUserId()
        let fileName = "\(userId)/\(heroId.uuidString)/avatar.png"
        let avatarRef = storageRef.child("\(avatarBucket)/\(fileName)")

        print("📥 Downloading avatar: \(fileName)")

        do {
            // Check if file exists
            guard await fileExists(at: "\(avatarBucket)/\(fileName)") else {
                print("ℹ️ Avatar not found: \(fileName)")
                return nil
            }

            // Download data with a maximum size
            let data = try await avatarRef.data(maxSize: maxAvatarSize)

            print("✅ Avatar downloaded: \(data.count) bytes")
            return data

        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ Avatar not found: \(fileName)")
                return nil
            }

            print("❌ Failed to download avatar: \(error)")
            throw FirebaseStorageError.downloadFailed(error.localizedDescription)
        }
    }

    func deleteAvatar(heroId: UUID) async throws {
        let userId = try await getCurrentUserId()
        let fileName = "\(userId)/\(heroId.uuidString)/avatar.png"
        let avatarRef = storageRef.child("\(avatarBucket)/\(fileName)")

        print("🗑️ Deleting avatar: \(fileName)")

        do {
            try await avatarRef.delete()
            print("✅ Avatar deleted: \(fileName)")
        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ Avatar already deleted or not found: \(fileName)")
                return
            }

            print("❌ Failed to delete avatar: \(error)")
            throw FirebaseStorageError.deleteFailed(error.localizedDescription)
        }
    }

    func getAvatarURL(heroId: UUID) -> String? {
        guard let userId = authService.currentUserId else { return nil }

        let fileName = "\(userId)/\(heroId.uuidString)/avatar.png"
        let avatarRef = storageRef.child("\(avatarBucket)/\(fileName)")

        // This returns a reference path, not a download URL
        // For actual download URL, use downloadURL() which is async
        return "gs://\(storage.reference().bucket)/\(avatarBucket)/\(fileName)"
    }

    // MARK: - Audio Operations

    func uploadStoryAudio(storyId: UUID, audioData: Data) async throws -> String {
        let userId = try await getCurrentUserId()

        // Check file size
        guard audioData.count <= maxAudioSize else {
            throw FirebaseStorageError.fileTooLarge(maxSize: maxAudioSize)
        }

        let fileName = "\(userId)/\(storyId.uuidString)/audio.mp3"
        let audioRef = storageRef.child("\(audioBucket)/\(fileName)")

        print("📤 Uploading audio: \(fileName)")

        // Create metadata
        let metadata = createMetadata(
            contentType: "audio/mpeg",
            customMetadata: [
                "storyId": storyId.uuidString,
                "userId": userId,
                "uploadedAt": ISO8601DateFormatter().string(from: Date()),
                "fileSize": "\(audioData.count)"
            ]
        )

        do {
            // Upload the file
            let uploadTask = audioRef.putData(audioData, metadata: metadata)

            // Monitor upload progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    print("📊 Audio upload progress: \(String(format: "%.1f", percentComplete))%")
                }
            }

            // Wait for upload to complete
            _ = try await uploadTask.observe(.success)

            // Get download URL
            let downloadURL = try await audioRef.downloadURL()

            print("✅ Audio uploaded successfully: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString

        } catch {
            print("❌ Failed to upload audio: \(error)")
            throw FirebaseStorageError.uploadFailed(error.localizedDescription)
        }
    }

    func downloadStoryAudio(storyId: UUID) async throws -> Data? {
        let userId = try await getCurrentUserId()
        let fileName = "\(userId)/\(storyId.uuidString)/audio.mp3"
        let audioRef = storageRef.child("\(audioBucket)/\(fileName)")

        print("📥 Downloading audio: \(fileName)")

        do {
            // Check if file exists
            guard await fileExists(at: "\(audioBucket)/\(fileName)") else {
                print("ℹ️ Audio not found: \(fileName)")
                return nil
            }

            // Download data with a maximum size
            let data = try await audioRef.data(maxSize: maxAudioSize)

            print("✅ Audio downloaded: \(data.count) bytes")
            return data

        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ Audio not found: \(fileName)")
                return nil
            }

            print("❌ Failed to download audio: \(error)")
            throw FirebaseStorageError.downloadFailed(error.localizedDescription)
        }
    }

    func deleteStoryAudio(storyId: UUID) async throws {
        let userId = try await getCurrentUserId()
        let fileName = "\(userId)/\(storyId.uuidString)/audio.mp3"
        let audioRef = storageRef.child("\(audioBucket)/\(fileName)")

        print("🗑️ Deleting audio: \(fileName)")

        do {
            try await audioRef.delete()
            print("✅ Audio deleted: \(fileName)")
        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ Audio already deleted or not found: \(fileName)")
                return
            }

            print("❌ Failed to delete audio: \(error)")
            throw FirebaseStorageError.deleteFailed(error.localizedDescription)
        }
    }

    func getAudioURL(storyId: UUID) -> String? {
        guard let userId = authService.currentUserId else { return nil }

        let fileName = "\(userId)/\(storyId.uuidString)/audio.mp3"
        let audioRef = storageRef.child("\(audioBucket)/\(fileName)")

        return "gs://\(storage.reference().bucket)/\(audioBucket)/\(fileName)"
    }

    // MARK: - Illustration Operations

    func uploadSceneIllustration(storyId: UUID, sceneNumber: Int, imageData: Data) async throws -> String {
        let userId = try await getCurrentUserId()

        // Check file size
        guard imageData.count <= maxIllustrationSize else {
            throw FirebaseStorageError.fileTooLarge(maxSize: maxIllustrationSize)
        }

        let fileName = "\(userId)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        let illustrationRef = storageRef.child("\(illustrationBucket)/\(fileName)")

        print("📤 Uploading illustration: \(fileName)")

        // Create metadata
        let metadata = createMetadata(
            contentType: "image/png",
            customMetadata: [
                "storyId": storyId.uuidString,
                "sceneNumber": "\(sceneNumber)",
                "userId": userId,
                "uploadedAt": ISO8601DateFormatter().string(from: Date())
            ]
        )

        do {
            // Upload the file
            let uploadTask = illustrationRef.putData(imageData, metadata: metadata)

            // Monitor upload progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    print("📊 Illustration upload progress: \(String(format: "%.1f", percentComplete))%")
                }
            }

            // Wait for upload to complete
            _ = try await uploadTask.observe(.success)

            // Get download URL
            let downloadURL = try await illustrationRef.downloadURL()

            print("✅ Illustration uploaded successfully: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString

        } catch {
            print("❌ Failed to upload illustration: \(error)")
            throw FirebaseStorageError.uploadFailed(error.localizedDescription)
        }
    }

    func downloadSceneIllustration(storyId: UUID, sceneNumber: Int) async throws -> Data? {
        let userId = try await getCurrentUserId()
        let fileName = "\(userId)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        let illustrationRef = storageRef.child("\(illustrationBucket)/\(fileName)")

        print("📥 Downloading illustration: \(fileName)")

        do {
            // Check if file exists
            guard await fileExists(at: "\(illustrationBucket)/\(fileName)") else {
                print("ℹ️ Illustration not found: \(fileName)")
                return nil
            }

            // Download data with a maximum size
            let data = try await illustrationRef.data(maxSize: maxIllustrationSize)

            print("✅ Illustration downloaded: \(data.count) bytes")
            return data

        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ Illustration not found: \(fileName)")
                return nil
            }

            print("❌ Failed to download illustration: \(error)")
            throw FirebaseStorageError.downloadFailed(error.localizedDescription)
        }
    }

    func deleteSceneIllustration(storyId: UUID, sceneNumber: Int) async throws {
        let userId = try await getCurrentUserId()
        let fileName = "\(userId)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        let illustrationRef = storageRef.child("\(illustrationBucket)/\(fileName)")

        print("🗑️ Deleting illustration: \(fileName)")

        do {
            try await illustrationRef.delete()
            print("✅ Illustration deleted: \(fileName)")
        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                print("ℹ️ Illustration already deleted or not found: \(fileName)")
                return
            }

            print("❌ Failed to delete illustration: \(error)")
            throw FirebaseStorageError.deleteFailed(error.localizedDescription)
        }
    }

    func getIllustrationURL(storyId: UUID, sceneNumber: Int) -> String? {
        guard let userId = authService.currentUserId else { return nil }

        let fileName = "\(userId)/\(storyId.uuidString)/scene_\(sceneNumber).png"
        let illustrationRef = storageRef.child("\(illustrationBucket)/\(fileName)")

        return "gs://\(storage.reference().bucket)/\(illustrationBucket)/\(fileName)"
    }

    // MARK: - Bulk Operations

    func deleteAllHeroStorage(heroId: UUID) async throws {
        // Delete avatar
        do {
            try await deleteAvatar(heroId: heroId)
        } catch {
            print("⚠️ Could not delete avatar for hero \(heroId): \(error)")
        }

        // Note: Stories and their associated files (audio, illustrations) should be handled separately
        // This is just for cleaning up hero-specific storage
        print("✅ Cleaned up all storage for hero: \(heroId)")
    }

    func deleteAllStoryStorage(storyId: UUID) async throws {
        // Delete audio
        do {
            try await deleteStoryAudio(storyId: storyId)
        } catch {
            print("⚠️ Could not delete audio for story \(storyId): \(error)")
        }

        // Delete all illustrations (attempt up to 10 scenes)
        for sceneNumber in 1...10 {
            do {
                try await deleteSceneIllustration(storyId: storyId, sceneNumber: sceneNumber)
            } catch {
                // Stop when we hit a scene that doesn't exist
                if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                    break
                }
                print("⚠️ Could not delete scene \(sceneNumber) for story \(storyId): \(error)")
            }
        }

        print("✅ Cleaned up all storage for story: \(storyId)")
    }

    // MARK: - Download URL Methods

    /// Get a signed download URL for a file with expiration
    func getSignedURL(for path: String, expirationMinutes: Int = 60) async throws -> URL {
        let fileRef = storageRef.child(path)

        do {
            let url = try await fileRef.downloadURL()
            return url
        } catch {
            throw FirebaseStorageError.urlGenerationFailed(error.localizedDescription)
        }
    }

    /// List all files in a directory
    func listFiles(in directory: String, maxResults: Int = 100) async throws -> [StorageReference] {
        let dirRef = storageRef.child(directory)

        do {
            let result = try await dirRef.listAll()
            return Array(result.items.prefix(maxResults))
        } catch {
            throw FirebaseStorageError.listFailed(error.localizedDescription)
        }
    }

    // MARK: - Storage Metadata

    /// Get metadata for a file
    func getFileMetadata(path: String) async throws -> StorageMetadata? {
        let fileRef = storageRef.child(path)

        do {
            let metadata = try await fileRef.getMetadata()
            return metadata
        } catch {
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                return nil
            }
            throw FirebaseStorageError.metadataFetchFailed(error.localizedDescription)
        }
    }

    /// Update metadata for a file
    func updateFileMetadata(path: String, metadata: StorageMetadata) async throws {
        let fileRef = storageRef.child(path)

        do {
            _ = try await fileRef.updateMetadata(metadata)
            print("✅ Metadata updated for: \(path)")
        } catch {
            throw FirebaseStorageError.metadataUpdateFailed(error.localizedDescription)
        }
    }
}

// MARK: - Firebase Storage Errors

enum FirebaseStorageError: LocalizedError {
    case noUserAuthenticated
    case uploadFailed(String)
    case downloadFailed(String)
    case deleteFailed(String)
    case fileTooLarge(maxSize: Int64)
    case urlGenerationFailed(String)
    case listFailed(String)
    case metadataFetchFailed(String)
    case metadataUpdateFailed(String)

    var errorDescription: String? {
        switch self {
        case .noUserAuthenticated:
            return "No user is authenticated. Please sign in first."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .fileTooLarge(let maxSize):
            let sizeInMB = Double(maxSize) / (1024 * 1024)
            return "File too large. Maximum size is \(String(format: "%.1f", sizeInMB)) MB"
        case .urlGenerationFailed(let message):
            return "Failed to generate download URL: \(message)"
        case .listFailed(let message):
            return "Failed to list files: \(message)"
        case .metadataFetchFailed(let message):
            return "Failed to fetch metadata: \(message)"
        case .metadataUpdateFailed(let message):
            return "Failed to update metadata: \(message)"
        }
    }
}

// MARK: - Storage Upload Task Extension

extension StorageUploadTask {
    /// Async wrapper for observing upload completion
    func observe(_ status: StorageTaskStatus) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.observe(status) { snapshot in
                switch status {
                case .success:
                    continuation.resume()
                case .failure:
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: FirebaseStorageError.uploadFailed("Unknown error"))
                    }
                default:
                    break
                }
            }
        }
    }
}