import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @EnvironmentObject private var schedulerState: SchedulerViewState
    @State private var launchAtLogin = false
    @State private var playlists: [PlaylistRecord] = []
    @State private var activePlaylistSelection: UUID?
    @State private var isLoadingPlaylists = false
    @State private var wallpaperCount = 0
    @State private var displayCount = 0
    @State private var playlistLoadError: String?
    @State private var launchAtLoginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                if let playlistLoadError {
                    SettingsInlineBanner(
                        title: "Unable to Load Playlists",
                        message: playlistLoadError
                    )
                }

                if let launchAtLoginError {
                    SettingsInlineBanner(
                        title: "Launch at Login Unavailable",
                        message: launchAtLoginError
                    )
                }

                automationCard
                libraryCard
                behaviorCard
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 760, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playlistStoreDidChange)) { _ in
            refreshPlaylists()
        }
        .onChange(of: schedulerState.activePlaylistID) { _ in
            syncSchedulerState()
        }
    }

    private func initialize() {
        checkLaunchAtLogin()
        syncSchedulerState()
        refreshPlaylists()
        refreshEnvironmentSummary()
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

    private func refreshEnvironmentSummary() {
        displayCount = services.wallpaperService.availableDisplays().count

        Task {
            let count: Int
            do {
                count = try await services.wallpaperService.fetchLibrary().count
            } catch {
                count = 0
            }

            await MainActor.run {
                wallpaperCount = count
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
        schedulerState.refresh(from: services.schedulerCoordinator)
        if let selected = schedulerState.activePlaylistID,
           playlists.contains(where: { $0.id == selected }) {
            activePlaylistSelection = selected
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.largeTitle.weight(.semibold))
            Text("Configure wallpaper rotation behavior, choose the active playlist, and review the current library setup.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                SettingsMetricChip(
                    label: "Rotation",
                    value: schedulerState.isRunning ? "Running" : "Paused"
                )
                SettingsMetricChip(
                    label: "Playlists",
                    value: "\(playlists.count)"
                )
                SettingsMetricChip(
                    label: "Library",
                    value: "\(wallpaperCount) wallpapers"
                )
                SettingsMetricChip(
                    label: "Displays",
                    value: "\(displayCount)"
                )
            }
        }
    }

    private var automationCard: some View {
        SettingsCard(title: "Automation", subtitle: "Control scheduling, startup behavior, and the playlist currently used for rotation.") {
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: Binding(
                    get: { schedulerState.isRunning },
                    set: { enabled in
                        if enabled {
                            services.schedulerCoordinator.start()
                        } else {
                            services.schedulerCoordinator.pause()
                        }
                        syncSchedulerState()
                    }
                )) {
                    SettingsRowText(
                        title: "Enable Rotation",
                        detail: schedulerState.isRunning
                            ? "Automatic wallpaper changes are currently active."
                            : "Wallpaper rotation is paused until you resume it."
                    )
                }
                .toggleStyle(.switch)

                if #available(macOS 13.0, *) {
                    Toggle(isOn: $launchAtLogin) {
                        SettingsRowText(
                            title: "Launch at Login",
                            detail: "Open WPswitcher automatically when you sign in."
                        )
                    }
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }
                } else {
                    SettingsRowText(
                        title: "Launch at Login",
                        detail: "Requires macOS 13 or newer."
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    SettingsRowText(
                        title: "Active Playlist",
                        detail: playlists.isEmpty
                            ? "Create a playlist in the main window before enabling rotation."
                            : "Select which playlist the scheduler should use."
                    )

                    if playlists.isEmpty {
                        Button("Open Main Window", action: openMainWindow)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                    } else {
                        Picker("Active Playlist", selection: Binding(
                            get: { activePlaylistSelection ?? playlists[0].id },
                            set: { selectedID in
                                guard activePlaylistSelection != selectedID else { return }
                                activePlaylistSelection = selectedID
                                services.schedulerCoordinator.setActivePlaylist(id: selectedID)
                                syncSchedulerState()
                            }
                        )) {
                            ForEach(playlists) { playlist in
                                Text(playlist.name).tag(playlist.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 320, alignment: .leading)
                    }
                }

                HStack(spacing: 12) {
                    Button("Refresh Playlists", action: refreshPlaylists)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(isLoadingPlaylists)

                    if isLoadingPlaylists {
                        ProgressView("Loading…")
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var libraryCard: some View {
        SettingsCard(title: "Library", subtitle: "Review the current asset inventory and connected display environment.") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsInfoRow(
                    label: "Wallpaper Library",
                    value: wallpaperCount == 0 ? "No imported wallpapers" : "\(wallpaperCount) wallpaper\(wallpaperCount == 1 ? "" : "s")"
                )
                SettingsInfoRow(
                    label: "Connected Displays",
                    value: displayCount == 0 ? "No displays detected" : "\(displayCount) display\(displayCount == 1 ? "" : "s") available"
                )
                SettingsInfoRow(
                    label: "Scheduler Playlist",
                    value: activePlaylistName
                )

                HStack(spacing: 12) {
                    Button("Open Main Window", action: openMainWindow)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                    Button("Refresh Library Summary") {
                        refreshEnvironmentSummary()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    private var behaviorCard: some View {
        SettingsCard(title: "Behavior", subtitle: "Notes about how WPswitcher applies wallpapers and schedules future changes.") {
            VStack(alignment: .leading, spacing: 14) {
                SettingsInfoRow(
                    label: "Rotation Interval",
                    value: "Configured per playlist in the editor."
                )
                SettingsInfoRow(
                    label: "Current Status",
                    value: schedulerState.isRunning ? "Scheduler is actively rotating wallpapers." : "Scheduler is paused."
                )
                SettingsInfoRow(
                    label: "Window Access",
                    value: "Use the menu bar icon or app commands to reopen the main window at any time."
                )
            }
        }
    }

    private var activePlaylistName: String {
        guard let activePlaylistSelection,
              let playlist = playlists.first(where: { $0.id == activePlaylistSelection })
        else {
            return "No playlist selected"
        }
        return playlist.name
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showMainWindowFromCommand")), to: nil, from: nil)
    }

    @available(macOS 13.0, *)
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin.toggle()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .underPageBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SettingsMetricChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct SettingsRowText: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.body.weight(.medium))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsInlineBanner: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ServiceRegistry.preview)
    }
}
#endif
