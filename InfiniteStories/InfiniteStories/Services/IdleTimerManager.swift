import Foundation
import UIKit
import os.log

final class IdleTimerManager {
    static let shared = IdleTimerManager()
    
    private var requestCount = 0
    private let queue = DispatchQueue(label: "com.infinitestories.idletimer", attributes: .concurrent)
    private let logger = Logger(subsystem: "com.infinitestories", category: "IdleTimerManager")
    
    private init() {}
    
    func disableIdleTimer(for context: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.requestCount += 1
            self.logger.info("Disabling idle timer for context: \(context). Request count: \(self.requestCount)")
            
            if self.requestCount == 1 {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                    self.logger.info("Idle timer disabled")
                }
            }
        }
    }
    
    func enableIdleTimer(for context: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.requestCount = max(0, self.requestCount - 1)
            self.logger.info("Enabling idle timer for context: \(context). Request count: \(self.requestCount)")
            
            if self.requestCount == 0 {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                    self.logger.info("Idle timer enabled")
                }
            }
        }
    }
    
    func reset() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.requestCount = 0
            self.logger.info("Resetting idle timer manager")
            
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
                self.logger.info("Idle timer reset to enabled state")
            }
        }
    }
    
    var currentRequestCount: Int {
        queue.sync {
            requestCount
        }
    }
}