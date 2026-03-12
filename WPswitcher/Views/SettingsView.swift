import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var selection: SettingsSection = .general
    @State private var launchAtLogin = false
    @State private var playlists: [PlaylistRecord] = []
    @State private var activePlaylistSelection: UUID?
    @State private var isLoadingPlaylists = false
    @State private var playlistLoadError: String?
    @State private var isRotationEnabled = false

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
            initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playlistStoreDidChange)) { _ in
            refreshPlaylists()
        }
        .onReceive(NotificationCenter.default.publisher(for: .schedulerCoordinatorStateDidChange)) { _ in
            syncSchedulerState()
        }
    }

    private func initialize() {
        checkLaunchAtLogin()
        syncSchedulerState()
        refreshPlaylists()
    }

    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func refreshPlaylists() {
        isLoadingPlaylists = true
        playlistLoadError = nil

        Task {
            do {
                let fetched = try await services.playlistStore.fetchPlaylists()
                let sorted = sortPlaylists(fetched)
                await MainActor.run {
                    playlists = sorted
                    isLoadingPlaylists = false
                    syncActivePlaylistSelection(with: sorted)
                }
            } catch {
                await MainActor.run {
                    playlists = []
                    activePlaylistSelection = nil
                    isLoadingPlaylists = false
                    playlistLoadError = error.localizedDescription
                }
            }
        }
    }

    private func sortPlaylists(_ records: [PlaylistRecord]) -> [PlaylistRecord] {
        records.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func syncActivePlaylistSelection(with playlists: [PlaylistRecord]) {
        if let selected = services.schedulerCoordinator.activePlaylistID,
           playlists.contains(where: { $0.id == selected }) {
            activePlaylistSelection = selected
            return
        }

        guard let fallback = playlists.first else {
            activePlaylistSelection = nil
            return
        }

        activePlaylistSelection = fallback.id
        services.schedulerCoordinator.setActivePlaylist(id: fallback.id)
    }

    private func syncSchedulerState() {
        isRotationEnabled = services.schedulerCoordinator.isRunning
        if let selected = services.schedulerCoordinator.activePlaylistID,
           playlists.contains(where: { $0.id == selected }) {
            activePlaylistSelection = selected
        }
    }

    private var generalSettings: some View {
        let status = isRotationEnabled ? "Yes" : "No"
        return Form {
            Toggle("Enable Rotation", isOn: Binding(
                get: { isRotationEnabled },
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

            LabeledContent("Active Playlist") {
                if playlists.isEmpty {
                    Text("No playlists available")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Active Playlist", selection: Binding(
                        get: { activePlaylistSelection ?? playlists[0].id },
                        set: { selectedID in
                            guard activePlaylistSelection != selectedID else { return }
                            activePlaylistSelection = selectedID
                            services.schedulerCoordinator.setActivePlaylist(id: selectedID)
                        }
                    )) {
                        ForEach(playlists) { playlist in
                            Text(playlist.name).tag(playlist.id)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: 280)
                }
            }

            if isLoadingPlaylists {
                ProgressView("Loading playlists…")
                    .controlSize(.small)
            } else {
                Button("Refresh Playlist List", action: refreshPlaylists)
                    .controlSize(.small)
            }

            if let playlistLoadError {
                Text("Playlist loading error: \(playlistLoadError)")
                    .font(.footnote)
                    .foregroundColor(.red)
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
