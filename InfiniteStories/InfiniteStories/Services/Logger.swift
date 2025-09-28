//
//  Logger.swift
//  InfiniteStories
//
//  Created by Assistant on 17/09/2025.
//

import Foundation

enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARN"
    case error = "❌ ERROR"
    case success = "✅ SUCCESS"
    case network = "🌐 NETWORK"
}

enum LogCategory: String {
    case story = "📚 STORY"
    case audio = "🎙️ AUDIO"
    case avatar = "🎨 AVATAR"
    case illustration = "🖼️ ILLUST"
    case api = "🔌 API"
    case cache = "💾 CACHE"
    case ui = "📱 UI"
}

class AppLogger {
    static let shared = AppLogger()

    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.infinitestories.logger", qos: .utility)
    private var sessionId = UUID().uuidString.prefix(8)

    // Enable/disable detailed logging for production
    var isVerbose: Bool = true
    var logToFile: Bool = false
    private var logFileURL: URL?

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        if logToFile {
            setupFileLogging()
        }
    }

    private func setupFileLogging() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "infinitestories_\(formatter.string(from: Date())).log"

        logFileURL = logsDirectory.appendingPathComponent(filename)
    }

    func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory? = nil,
        requestId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        guard isVerbose || level == .error || level == .warning else { return }

        logQueue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = self.dateFormatter.string(from: Date())
            let categoryStr = category?.rawValue ?? ""
            let requestStr = requestId != nil ? "[\(requestId!)]" : ""

            var logMessage = "\(timestamp) \(level.rawValue) \(categoryStr) \(requestStr) \(message)"

            // Add metadata if provided
            if let metadata = metadata, !metadata.isEmpty {
                let metadataStr = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                logMessage += " | \(metadataStr)"
            }

            // Print to console
            print(logMessage)

            // Write to file if enabled
            if self.logToFile, let logFileURL = self.logFileURL {
                self.writeToFile(logMessage, url: logFileURL)
            }
        }
    }

    private func writeToFile(_ message: String, url: URL) {
        let logEntry = message + "\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - Convenience Methods

    func debug(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
        log(message, level: .debug, category: category, requestId: requestId)
    }

    func info(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
        log(message, level: .info, category: category, requestId: requestId)
    }

    func warning(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
        log(message, level: .warning, category: category, requestId: requestId)
    }

    func error(_ message: String, category: LogCategory? = nil, requestId: String? = nil, error: Error? = nil) {
        var metadata: [String: Any]? = nil
        if let error = error {
            metadata = ["error": error.localizedDescription]
        }
        log(message, level: .error, category: category, requestId: requestId, metadata: metadata)
    }

    func success(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
        log(message, level: .success, category: category, requestId: requestId)
    }

    func network(_ message: String, requestId: String? = nil, metadata: [String: Any]? = nil) {
        log(message, level: .network, category: .api, requestId: requestId, metadata: metadata)
    }

    // MARK: - Performance Logging

    func logPerformance(operation: String, startTime: Date, requestId: String? = nil) {
        let duration = Date().timeIntervalSince(startTime)
        let durationStr = String(format: "%.3f", duration)

        let performanceLevel: LogLevel = duration < 1.0 ? .info : (duration < 3.0 ? .warning : .error)

        log("\(operation) completed in \(durationStr)s",
            level: performanceLevel,
            category: .api,
            requestId: requestId,
            metadata: ["duration": durationStr])
    }

    // MARK: - Request/Response Logging

    func logRequest(url: String, method: String, requestId: String, bodySize: Int? = nil) {
        var metadata: [String: Any] = [
            "method": method,
            "url": url
        ]

        if let bodySize = bodySize {
            metadata["bodySize"] = "\(bodySize) bytes"
        }

        network("API Request: \(method) \(url)", requestId: requestId, metadata: metadata)
    }

    func logResponse(statusCode: Int, responseTime: TimeInterval, requestId: String, dataSize: Int? = nil) {
        var metadata: [String: Any] = [
            "status": statusCode,
            "responseTime": String(format: "%.2f", responseTime) + "s"
        ]

        if let dataSize = dataSize {
            metadata["dataSize"] = "\(dataSize) bytes"
        }

        let level: LogLevel = statusCode == 200 ? .success : (statusCode >= 400 ? .error : .warning)

        log("API Response: HTTP \(statusCode)",
            level: level,
            category: .api,
            requestId: requestId,
            metadata: metadata)
    }

    // MARK: - Story Generation Logging

    func logStoryGeneration(hero: String, event: String, language: String, requestId: String) {
        info("Story generation started",
             category: .story,
             requestId: requestId)

        let metadata: [String: Any] = [
            "hero": hero,
            "event": event,
            "language": language
        ]

        log("Story parameters",
            level: .debug,
            category: .story,
            requestId: requestId,
            metadata: metadata)
    }

    // MARK: - Prompt Logging

    func logPrompt(_ prompt: String, type: String = "DALL-E", requestId: String? = nil, hero: String? = nil) {
        let promptLength = prompt.count
        let promptWords = prompt.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count

        // Extract keywords (simple approach - look for common descriptive words)
        let keywords = extractKeywords(from: prompt)

        // Check for potential issues
        let warnings = validatePrompt(prompt)

        var metadata: [String: Any] = [
            "type": type,
            "length": promptLength,
            "words": promptWords,
            "keywords": keywords.joined(separator: ", ")
        ]

        if let hero = hero {
            metadata["hero"] = hero
        }

        if !warnings.isEmpty {
            metadata["warnings"] = warnings.joined(separator: "; ")
            warning("Prompt validation warnings", category: .illustration, requestId: requestId)
            for warning in warnings {
                self.warning("  - \(warning)", category: .illustration, requestId: requestId)
            }
        }

        // Log the prompt header with metadata
        info("AI Prompt [\(type)]", category: .illustration, requestId: requestId)
        debug("Prompt Stats - Length: \(promptLength) chars, Words: \(promptWords)", category: .illustration, requestId: requestId)

        // Log the full prompt
        info("=== FULL PROMPT START ===", category: .illustration, requestId: requestId)

        // Split long prompts into readable chunks
        let chunkSize = 200
        if prompt.count > chunkSize {
            for i in stride(from: 0, to: prompt.count, by: chunkSize) {
                let endIndex = min(i + chunkSize, prompt.count)
                let startIdx = prompt.index(prompt.startIndex, offsetBy: i)
                let endIdx = prompt.index(prompt.startIndex, offsetBy: endIndex)
                let chunk = String(prompt[startIdx..<endIdx])
                info(chunk, category: .illustration, requestId: requestId)
            }
        } else {
            info(prompt, category: .illustration, requestId: requestId)
        }

        info("=== FULL PROMPT END ===", category: .illustration, requestId: requestId)

        // Save to file if debug mode is enabled
        #if DEBUG
        savePromptToFile(prompt: prompt, type: type, requestId: requestId, metadata: metadata)
        #endif
    }

    func logDALLERequest(prompt: String, size: String, quality: String, requestId: String) {
        info("🎨 DALL-E Request", category: .illustration, requestId: requestId)
        info("❗ SAVING OPENAI PLAYGROUND COMMAND FILE...", category: .illustration, requestId: requestId)
        debug("Parameters - Size: \(size), Quality: \(quality)", category: .illustration, requestId: requestId)
        logPrompt(prompt, type: "DALL-E", requestId: requestId)

        // Save OpenAI Playground command to file for easy replay
        info("💾 Attempting to save OpenAI Playground command...", category: .illustration, requestId: requestId)
        saveOpenAIPlaygroundCommand(prompt: prompt, size: size, quality: quality, requestId: requestId)
        info("✅ OpenAI Playground command save process completed", category: .illustration, requestId: requestId)
    }

    func logDALLEResponse(success: Bool, revisedPrompt: String? = nil, imageSize: Int? = nil, requestId: String, error: Error? = nil) {
        if success {
            self.success("DALL-E Response received", category: .illustration, requestId: requestId)
            if let revisedPrompt = revisedPrompt {
                info("Revised Prompt from DALL-E:", category: .illustration, requestId: requestId)
                info(revisedPrompt, category: .illustration, requestId: requestId)
            }
            if let imageSize = imageSize {
                info("Image size: \(imageSize) bytes (\(imageSize / 1024) KB)", category: .illustration, requestId: requestId)
            }
        } else {
            self.error("DALL-E Request failed", category: .illustration, requestId: requestId, error: error)
        }
    }

    private func extractKeywords(from prompt: String) -> [String] {
        let commonWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from", "as", "is", "was", "are", "were", "been", "be", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "shall", "can", "need"])

        let words = prompt.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count > 3 && !commonWords.contains($0) }

        // Get unique keywords, limit to 10
        let uniqueWords = Array(Set(words))
        return Array(uniqueWords.prefix(10))
    }

    private func validatePrompt(_ prompt: String) -> [String] {
        var warnings: [String] = []

        // Check length
        if prompt.count > 4000 {
            warnings.append("Prompt exceeds 4000 characters (\(prompt.count) chars)")
        } else if prompt.count > 3000 {
            warnings.append("Prompt is very long (\(prompt.count) chars)")
        }

        if prompt.count < 20 {
            warnings.append("Prompt is very short (\(prompt.count) chars)")
        }

        // Check for potential issues
        if prompt.contains("NSFW") || prompt.contains("violent") || prompt.contains("gore") {
            warnings.append("Prompt contains potentially inappropriate content")
        }

        // Check for special characters that might cause issues
        let specialChars = ["<", ">", "{", "}", "[", "]", "|", "\\"]
        for char in specialChars {
            if prompt.contains(char) {
                warnings.append("Prompt contains special character: \(char)")
            }
        }

        // Check if prompt seems to be missing key elements
        if !prompt.lowercased().contains("style") && !prompt.lowercased().contains("illustration") {
            warnings.append("Prompt may be missing style/illustration instructions")
        }

        return warnings
    }

    // MARK: - OpenAI Playground Export

    private func printOpenAIPlaygroundCommand(prompt: String, size: String, quality: String, requestId: String) {
        info("📢 === COPY THIS FOR OPENAI PLAYGROUND ===", category: .illustration, requestId: requestId)
        info("🌐 Go to: https://platform.openai.com/playground", category: .illustration, requestId: requestId)
        info("🎨 Select: DALL-E 3 Model", category: .illustration, requestId: requestId)
        info("💳 Settings:", category: .illustration, requestId: requestId)
        info("  - Size: \(size)", category: .illustration, requestId: requestId)
        info("  - Quality: \(quality)", category: .illustration, requestId: requestId)
        info("📝 === PROMPT TO PASTE (START) ===", category: .illustration, requestId: requestId)

        // Split long prompts into lines for better readability
        let lines = prompt.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            info(String(line), category: .illustration, requestId: requestId)
        }

        info("📝 === PROMPT TO PASTE (END) ===", category: .illustration, requestId: requestId)
        info("📢 === END OF PLAYGROUND COMMAND ===", category: .illustration, requestId: requestId)
    }

    func listOpenAIPlaygroundFiles() {
        info("📁 === OPENAI PLAYGROUND FILES ===", category: .illustration)

        #if os(macOS)
        // Check user Documents folder on macOS
        let userDocumentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
            .appendingPathComponent("OpenAI_Playground")
        #else
        // On iOS, we only have sandbox
        let userDocumentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpenAI_Playground_User")
        #endif

        info("📂 Checking: \(userDocumentsPath.path)", category: .illustration)

        do {
            let files = try FileManager.default.contentsOfDirectory(at: userDocumentsPath, includingPropertiesForKeys: nil)
            if files.isEmpty {
                info("⚠️ No files found in user Documents/OpenAI_Playground", category: .illustration)
            } else {
                info("✅ Found \(files.count) files:", category: .illustration)
                for file in files {
                    info("  - \(file.lastPathComponent)", category: .illustration)
                }
            }
        } catch {
            info("❌ Error reading user Documents: \(error)", category: .illustration)
        }

        // Check sandbox folder
        let sandboxPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpenAI_Playground")

        info("🗂 Checking sandbox: \(sandboxPath.path)", category: .illustration)

        do {
            let files = try FileManager.default.contentsOfDirectory(at: sandboxPath, includingPropertiesForKeys: nil)
            if files.isEmpty {
                info("⚠️ No files found in sandbox", category: .illustration)
            } else {
                info("✅ Found \(files.count) sandbox files", category: .illustration)
            }
        } catch {
            info("❌ Error reading sandbox: \(error)", category: .illustration)
        }

        info("🎯 To open in Finder: open ~/Documents/OpenAI_Playground/", category: .illustration)
    }

    // MARK: - OpenAI Playground Export

    func saveOpenAIPlaygroundCommand(prompt: String, size: String, quality: String, requestId: String) {
        info("🔄 === OPENAI PLAYGROUND EXPORT STARTED ===", category: .illustration, requestId: requestId)

        // First, always print to console for immediate access
        printOpenAIPlaygroundCommand(prompt: prompt, size: size, quality: quality, requestId: requestId)

        // Save to app's sandbox for app access (this should always work)
        let sandboxDocumentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sandboxPlaygroundDirectory = sandboxDocumentsPath.appendingPathComponent("OpenAI_Playground")

        // For iOS, we can only use the sandbox
        #if os(macOS)
        // Try to save to user's Documents folder on macOS
        let userDocumentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
            .appendingPathComponent("OpenAI_Playground")
        #else
        // On iOS, use a secondary sandbox location
        let userDocumentsPath = sandboxDocumentsPath.appendingPathComponent("OpenAI_Playground_User")
        #endif

        // Primary directory is sandbox (guaranteed to work)
        let playgroundDirectory = sandboxPlaygroundDirectory

        // Create sandbox directory first (should always work)
        do {
            try FileManager.default.createDirectory(at: sandboxPlaygroundDirectory, withIntermediateDirectories: true, attributes: nil)
            info("✅ Created sandbox directory: \(sandboxPlaygroundDirectory.path)", category: .illustration, requestId: requestId)
        } catch {
            self.error("❌ Failed to create sandbox directory: \(error)", category: .illustration, requestId: requestId, error: error)
        }

        #if os(macOS)
        // Try to create user Documents directory on macOS
        do {
            try FileManager.default.createDirectory(at: userDocumentsPath, withIntermediateDirectories: true, attributes: nil)
            info("✅ Created user Documents directory: \(userDocumentsPath.path)", category: .illustration, requestId: requestId)
        } catch {
            info("⚠️ Could not create user Documents directory (sandbox restriction): \(error)", category: .illustration, requestId: requestId)
        }
        #endif

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "DALLE_\(requestId)_\(timestamp).txt"

        // Unused variable warning fix
        _ = playgroundDirectory.appendingPathComponent(filename)

        var content = "=== OPENAI PLAYGROUND COMMAND ===\n"
        content += "Generated: \(Date())\n"
        content += "Request ID: \(requestId)\n\n"

        content += "🌐 PLAYGROUND URL:\n"
        content += "https://platform.openai.com/playground\n\n"

        content += "⚙️ SETTINGS:\n"
        content += "Model: dall-e-3\n"
        content += "Size: \(size)\n"
        content += "Quality: \(quality)\n"
        content += "Number of images: 1\n\n"

        content += "📝 PROMPT TO PASTE:\n"
        content += "---START---\n"
        content += prompt
        content += "\n---END---\n\n"

        content += "📋 CURL COMMAND (for terminal):\n"
        content += "curl https://api.openai.com/v1/images/generations \\\n"
        content += "  -H \"Content-Type: application/json\" \\\n"
        content += "  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n"
        content += "  -d '{\n"
        content += "    \"model\": \"dall-e-3\",\n"
        content += "    \"prompt\": \"\(prompt.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n"))\",\n"
        content += "    \"n\": 1,\n"
        content += "    \"size\": \"\(size)\",\n"
        content += "    \"quality\": \"\(quality)\",\n"
        content += "    \"response_format\": \"b64_json\"\n"
        content += "  }'\n\n"

        content += "=== END ===\n"

        // Save to sandbox first (should always work)
        let sandboxFileURL = sandboxPlaygroundDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: sandboxFileURL, atomically: true, encoding: .utf8)
            info("✅ SAVED TO SANDBOX: \(filename)", category: .illustration, requestId: requestId)
            info("📂 SANDBOX PATH: \(sandboxFileURL.path)", category: .illustration, requestId: requestId)

            // Print command to open the file
            info("📟 TO OPEN FILE, RUN:", category: .illustration, requestId: requestId)
            info("open \"\(sandboxFileURL.path)\"", category: .illustration, requestId: requestId)
            info("📁 TO OPEN FOLDER, RUN:", category: .illustration, requestId: requestId)
            info("open \"\(sandboxPlaygroundDirectory.path)\"", category: .illustration, requestId: requestId)
        } catch {
            self.error("❌ Failed to save to sandbox: \(error.localizedDescription)", category: .illustration, requestId: requestId, error: error)
        }

        #if os(macOS)
        // Try to also save to user Documents on macOS
        let userFileURL = userDocumentsPath.appendingPathComponent(filename)
        do {
            try content.write(to: userFileURL, atomically: true, encoding: .utf8)
            info("✅ ALSO SAVED TO USER DOCUMENTS: ~/Documents/OpenAI_Playground/\(filename)", category: .illustration, requestId: requestId)
        } catch {
            // This is expected to fail in sandboxed apps
            debug("Could not save to user Documents (expected in sandbox): \(error)", category: .illustration, requestId: requestId)
        }
        #endif

        info("🎉 === OPENAI PLAYGROUND EXPORT COMPLETED ===", category: .illustration, requestId: requestId)
    }

    #if DEBUG
    private func savePromptToFile(prompt: String, type: String, requestId: String?, metadata: [String: Any]) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let promptsDirectory = documentsPath.appendingPathComponent("Prompts")

        try? FileManager.default.createDirectory(at: promptsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: Date())
        let reqId = requestId ?? "unknown"
        let filename = "\(type)_\(reqId)_\(timestamp).txt"

        let fileURL = promptsDirectory.appendingPathComponent(filename)

        var content = "=== AI PROMPT DEBUG FILE ===\n"
        content += "Generated: \(Date())\n"
        content += "Type: \(type)\n"
        content += "Request ID: \(reqId)\n"
        content += "\n=== METADATA ===\n"

        for (key, value) in metadata {
            content += "\(key): \(value)\n"
        }

        content += "\n=== PROMPT ===\n"
        content += prompt
        content += "\n\n=== END ===\n"

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            debug("Saved prompt to: \(filename)", category: .illustration)
        } catch {
            self.error("Failed to save prompt to file", category: .illustration, error: error)
        }
    }
    #endif

    // MARK: - Cleanup

    func cleanupOldLogs(daysToKeep: Int = 7) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let logsDirectory = documentsPath.appendingPathComponent("Logs")

        do {
            let files = try FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
            let cutoffDate = Date().addingTimeInterval(-Double(daysToKeep * 24 * 60 * 60))

            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: file)
                    debug("Deleted old log file: \(file.lastPathComponent)", category: .cache)
                }
            }
        } catch {
            self.error("Failed to cleanup old logs", category: .cache, error: error)
        }
    }
}

// MARK: - Global Convenience Functions

func logDebug(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
    AppLogger.shared.debug(message, category: category, requestId: requestId)
}

func logInfo(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
    AppLogger.shared.info(message, category: category, requestId: requestId)
}

func logWarning(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
    AppLogger.shared.warning(message, category: category, requestId: requestId)
}

func logError(_ message: String, category: LogCategory? = nil, requestId: String? = nil, error: Error? = nil) {
    AppLogger.shared.error(message, category: category, requestId: requestId, error: error)
}

func logSuccess(_ message: String, category: LogCategory? = nil, requestId: String? = nil) {
    AppLogger.shared.success(message, category: category, requestId: requestId)
}
