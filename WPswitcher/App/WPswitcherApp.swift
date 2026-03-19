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
                .environmentObject(services.schedulerState)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Hide Main Window") {
                    appDelegate.hideMainWindowFromCommand()
                }
                .keyboardShortcut("9")

                Button("Show Main Window") {
                    appDelegate.showMainWindowFromCommand()
                }
                .keyboardShortcut("0")

                Divider()

                Button("Show Quick Access") {
                    appDelegate.showCompactWindowFromCommand()
                }
                .keyboardShortcut("8")

                Button("Hide Quick Access") {
                    appDelegate.hideCompactWindowFromCommand()
                }
                .keyboardShortcut("7")
            }
        }
    }
}
