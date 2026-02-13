import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var selection: SettingsSection = .general
    @State private var launchAtLogin = false

    var body: some View {
        TabView(selection: $selection) {
            generalSettings
                .tag(SettingsSection.general)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 720, height: 520)
        .onAppear {
            checkLaunchAtLogin()
        }
    }

    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var generalSettings: some View {
        let status = services.schedulerCoordinator.isRunning ? "Yes" : "No"
        return Form {
            Toggle("Enable Rotation", isOn: Binding(
                get: { services.schedulerCoordinator.isRunning },
                set: { enabled in
                    if enabled {
                        services.schedulerCoordinator.start()
                    } else {
                        services.schedulerCoordinator.pause()
                    }
                }
            ))

            if #available(macOS 13.0, *) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }
            }
            
            Text("Rotation Interval is configured per-playlist.")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Text("Scheduler running: \(status)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(24)
    }

    @available(macOS 13.0, *)
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}

private enum SettingsSection: Hashable {
    case general
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ServiceRegistry.preview)
    }
}
#endif
