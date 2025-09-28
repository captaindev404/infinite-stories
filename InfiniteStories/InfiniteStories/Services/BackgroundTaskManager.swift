import Foundation
import UIKit
import BackgroundTasks
import os.log

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    static let storyGenerationTaskIdentifier = "com.infinitestories.storygeneration"
    static let audioProcessingTaskIdentifier = "com.infinitestories.audioprocessing"
    
    private let logger = Logger(subsystem: "com.infinitestories", category: "BackgroundTaskManager")
    private var activeBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.storyGenerationTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleStoryGenerationTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.audioProcessingTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleAudioProcessingTask(task as! BGProcessingTask)
        }
        
        logger.info("Background tasks registered")
    }
    
    func scheduleStoryGenerationTask() {
        // Only schedule if handlers are registered
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            logger.info("Skipping background task scheduling in test environment")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: Self.storyGenerationTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Give more time before first run
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Story generation background task scheduled")
        } catch {
            logger.error("Failed to schedule story generation task: \(error.localizedDescription)")
        }
    }
    
    func scheduleAudioProcessingTask() {
        // Only schedule if handlers are registered
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            logger.info("Skipping background task scheduling in test environment")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: Self.audioProcessingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Give more time before first run
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Audio processing background task scheduled")
        } catch {
            logger.error("Failed to schedule audio processing task: \(error.localizedDescription)")
        }
    }
    
    func beginBackgroundTask(withName name: String, expirationHandler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier {
        let taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.logger.warning("Background task \(name) is about to expire")
            expirationHandler?()
            if let taskId = self?.activeBackgroundTask, taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
                self?.activeBackgroundTask = .invalid
            }
        }
        
        activeBackgroundTask = taskId
        logger.info("Started background task: \(name) with ID: \(taskId.rawValue)")
        return taskId
    }
    
    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        if identifier != .invalid {
            UIApplication.shared.endBackgroundTask(identifier)
            logger.info("Ended background task with ID: \(identifier.rawValue)")
            if identifier == activeBackgroundTask {
                activeBackgroundTask = .invalid
            }
        }
    }
    
    private func handleStoryGenerationTask(_ task: BGProcessingTask) {
        logger.info("Handling story generation background task")
        
        task.expirationHandler = { [weak self] in
            self?.logger.warning("Story generation task expired")
            task.setTaskCompleted(success: false)
        }
        
        NotificationCenter.default.post(
            name: .resumeStoryGeneration,
            object: nil,
            userInfo: ["backgroundTask": task]
        )
    }
    
    private func handleAudioProcessingTask(_ task: BGProcessingTask) {
        logger.info("Handling audio processing background task")
        
        task.expirationHandler = { [weak self] in
            self?.logger.warning("Audio processing task expired")
            task.setTaskCompleted(success: false)
        }
        
        NotificationCenter.default.post(
            name: .resumeAudioProcessing,
            object: nil,
            userInfo: ["backgroundTask": task]
        )
    }
}

extension Notification.Name {
    static let resumeStoryGeneration = Notification.Name("resumeStoryGeneration")
    static let resumeAudioProcessing = Notification.Name("resumeAudioProcessing")
}