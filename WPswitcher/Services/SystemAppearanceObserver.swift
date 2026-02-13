import AppKit
import Combine
import os.log

final class SystemAppearanceObserver: AppearanceObserver {
    private let notificationCenter: NotificationCenter
    private var observation: NSKeyValueObservation?
    private let logger = Logger(subsystem: "com.example.WPswitcher", category: "AppearanceObserver")

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func startObserving() {
        guard observation == nil else { return }
        
        logger.log("Starting system appearance observation")
        
        // Observe NSApp.effectiveAppearance
        // We need to ensure NSApp is available (it is in a running app)
        if let app = NSApp {
            observation = app.observe(\.effectiveAppearance) { [weak self] app, _ in
                self?.handleAppearanceChange(app.effectiveAppearance)
            }
        } else {
             logger.error("NSApp not available to observe appearance")
        }
    }

    func stopObserving() {
        observation?.invalidate()
        observation = nil
        logger.log("Stopped system appearance observation")
    }

    private func handleAppearanceChange(_ appearance: NSAppearance) {
        logger.log("System appearance changed: \(appearance.name.rawValue, privacy: .public)")
        notificationCenter.post(name: .appearanceDidChange, object: nil)
    }
}

extension Notification.Name {
    static let appearanceDidChange = Notification.Name("WPswitcher.AppearanceDidChange")
}
