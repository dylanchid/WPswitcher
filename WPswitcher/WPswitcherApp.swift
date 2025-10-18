import SwiftUI

@main
struct WPswitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let services = ServiceRegistry()

    init() {
        appDelegate.configure(with: services)
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(services)
        }
    }
}
