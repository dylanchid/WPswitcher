import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var selection: SettingsSection = .general
    @State private var isRotationEnabled = true
    @State private var intervalMinutes = 15

    var body: some View {
        TabView(selection: $selection) {
            generalSettings
                .tag(SettingsSection.general)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            WallpaperBrowserView()
                .tag(SettingsSection.library)
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle")
                }
        }
        .frame(width: 720, height: 520)
    }

    private var generalSettings: some View {
        let status = services.schedulerCoordinator.isRunning ? "Yes" : "No"
        return Form {
            Toggle("Enable Rotation", isOn: $isRotationEnabled)
            Stepper(value: $intervalMinutes, in: 1...240, step: 5) {
                Text("Interval: \(intervalMinutes) minutes")
            }
            Text("Settings are placeholders until scheduler is implemented.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Scheduler running: \(status)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(24)
    }
}

private enum SettingsSection: Hashable {
    case general
    case library
}

#Preview {
    SettingsView()
        .environmentObject(ServiceRegistry.preview)
}
