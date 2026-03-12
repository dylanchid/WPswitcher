import Foundation

enum AppEnvironment {
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    static let userDefaults: UserDefaults = {
        let processInfo = ProcessInfo.processInfo

        if let suiteName = processInfo.environment["WPS_DEFAULTS_SUITE"],
           let defaults = UserDefaults(suiteName: suiteName) {
            if processInfo.arguments.contains("--reset-defaults") {
                defaults.removePersistentDomain(forName: suiteName)
            }
            return defaults
        }

        return .standard
    }()
}
