import AppKit
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var selection: MainDestination? = .library
    @State private var playlists: [PlaylistRecord] = []
    @State private var playlistError: String?
    /// Sidebar closed by default; toggled via toolbar button.
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
        } detail: {
            detailContent
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sidebarVisibility = sidebarVisibility == .detailOnly ? .doubleColumn : .detailOnly
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .help("Toggle Sidebar")
                    }
                }
        }
        .frame(minWidth: 560, minHeight: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear(perform: refreshPlaylists)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPlaylists()
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Features") {
                NavigationLink(value: MainDestination.library) {
                    Label("Wallpaper Library", systemImage: "photo.on.rectangle")
                }
            }

            Section("Playlists") {
                Button(action: createPlaylist) {
                    Label("New Playlist", systemImage: "plus")
                }
                .buttonStyle(.plain)

                if playlists.isEmpty {
                    Label("No playlists yet", systemImage: "music.note.list")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: MainDestination.playlist(playlist.id)) {
                            Label(playlist.name, systemImage: "music.note.list")
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deletePlaylist(playlist.id)
                            } label: {
                                Label("Delete Playlist", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button(action: openPreferences) {
                    Label("Preferences…", systemImage: "gearshape")
                }
                .buttonStyle(.plain)

                Button(action: quitApplication) {
                    Label("Quit WPswitcher", systemImage: "power")
                }
                .buttonStyle(.plain)
            }

            if let playlistError {
                Section {
                    Text("Playlist error: \(playlistError)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .library {
        case .library:
            WallpaperLibraryView()
        case .playlist(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                PlaylistEditorHost(
                    playlist: playlist,
                    services: services,
                    onSave: handlePlaylistSaved
                )
                .id(playlist.id)
            } else {
                MissingSelectionPlaceholder(
                    title: "Playlist Not Found",
                    message: "Select another playlist or refresh."
                )
            }
        }
    }

    private func refreshPlaylists() {
        Task {
            do {
                let fetched = try await services.playlistStore.fetchPlaylists()
                await MainActor.run {
                    playlists = fetched
                    playlistError = nil
                    ensureValidSelection()
                }
            } catch {
                await MainActor.run {
                    playlists = []
                    playlistError = error.localizedDescription
                }
            }
        }
    }

    private func ensureValidSelection() {
        if case let .playlist(id) = selection,
           !playlists.contains(where: { $0.id == id }) {
            selection = .library
        }
    }

    private var selectedPlaylistID: UUID? {
        if case let .playlist(id) = selection {
            return id
        }
        return nil
    }

    private func playableEntry(for playlist: PlaylistRecord) -> PlaylistEntryRecord? {
        playlist.entries.first { $0.lightWallpaper != nil || $0.darkWallpaper != nil }
    }

    private func previewText(for playlist: PlaylistRecord) -> String {
        if playlist.entries.isEmpty {
            return "No entries"
        }
        if let entry = playableEntry(for: playlist) {
            if let wallpaper = entry.lightWallpaper ?? entry.darkWallpaper {
                return "Preview: \(wallpaper.displayName)"
            }
            return "Ready to preview"
        }
        return "Add wallpapers to preview"
    }

    private func applyPlaylistNow(_ playlist: PlaylistRecord) {
        guard let entry = playableEntry(for: playlist) else {
            playlistError = "Playlist \(playlist.name) has no playable entries."
            return
        }

        Task {
            let applied = services.wallpaperService.apply(entry: entry, from: playlist)
            await MainActor.run {
                playlistError = applied ? nil : "Unable to apply \(playlist.name) right now."
            }
        }
    }

    private func handlePlaylistSaved(_ record: PlaylistRecord) {
        if let index = playlists.firstIndex(where: { $0.id == record.id }) {
            playlists[index] = record
        } else {
            playlists.append(record)
        }
        playlists.sort { $0.createdAt < $1.createdAt }
        playlistError = nil
    }

    private func createPlaylist() {
        let draft = PlaylistDraft(
            id: nil,
            name: "Untitled Playlist",
            intervalMinutes: 15,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        Task {
            do {
                let record = try await services.playlistStore.createPlaylist(draft)
                await MainActor.run {
                    handlePlaylistSaved(record)
                    selection = .playlist(record.id)
                }
            } catch {
                await MainActor.run {
                    playlistError = error.localizedDescription
                }
            }
        }
    }

    private func deletePlaylist(_ id: UUID) {
        Task {
            do {
                try await services.playlistStore.deletePlaylist(id: id)
                await MainActor.run {
                    playlists.removeAll { $0.id == id }
                    playlistError = nil
                    ensureValidSelection()
                }
            } catch {
                await MainActor.run {
                    playlistError = error.localizedDescription
                }
            }
        }
    }

    private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    private func quitApplication() {
        NSApp.terminate(nil)
    }
}

private enum MainDestination: Hashable {
    case library
    case playlist(UUID)
}

private struct PlaylistEditorHost: View {
    private let playlist: PlaylistRecord
    private let onSave: (PlaylistRecord) -> Void
    @StateObject private var viewModel: PlaylistEditorViewModel

    init(playlist: PlaylistRecord, services: ServiceRegistry, onSave: @escaping (PlaylistRecord) -> Void) {
        self.playlist = playlist
        self.onSave = onSave
        _viewModel = StateObject(
            wrappedValue: PlaylistEditorViewModel(
                playlist: playlist,
                playlistStore: services.playlistStore,
                wallpaperService: services.wallpaperService,
                onSave: onSave
            )
        )
    }

    var body: some View {
        PlaylistEditorView(viewModel: viewModel)
            .onChange(of: playlist) { newValue in
                DispatchQueue.main.async {
                    viewModel.applyUpdatedRecord(newValue)
                }
            }
    }
}

private struct MissingSelectionPlaceholder: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title3)
                .bold()
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(nsColor: .textBackgroundColor))
    }
}

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView()
            .environmentObject(ServiceRegistry.preview)
    }
}
#endif
