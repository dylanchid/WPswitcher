import AppKit
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var selection: MainDestination? = .library
    @State private var playlists: [PlaylistRecord] = []
    @State private var playlistError: String?
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
        } detail: {
            detailContent
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .help("Toggle Sidebar")
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 920, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshPlaylists)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPlaylists()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: $selection) {
                Section("Workspace") {
                    NavigationLink(value: MainDestination.library) {
                        Label("Library", systemImage: "photo.on.rectangle.angled")
                    }
                }

                Section {
                    Button(action: createPlaylist) {
                        Label("New Playlist", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                } header: {
                    HStack {
                        Text("Playlists")
                        Spacer()
                        Text("\(playlists.count)")
                    }
                }

                if playlists.isEmpty {
                    Label("No playlists yet", systemImage: "music.note.list")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: MainDestination.playlist(playlist.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .lineLimit(1)
                                Text("\(playlist.entries.count) entries")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                Section("App") {
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
        .frame(minWidth: 250, idealWidth: 270, maxWidth: 300, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WPswitcher")
                .font(.title3.weight(.semibold))
            Text("Manage your wallpaper library and rotation playlists.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .library {
        case .library:
            LibraryDashboardView(
                playlists: playlists,
                selectedPlaylistID: selectedPlaylistID,
                playlistError: playlistError,
                onSelectPlaylist: { id in
                    selection = .playlist(id)
                },
                onCreatePlaylist: createPlaylist,
                onPlayNow: applyPlaylistNow,
                onDeletePlaylist: deletePlaylist,
                previewTextProvider: previewText,
                canPlayProvider: canPlay
            )
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

    private func canPlay(_ playlist: PlaylistRecord) -> Bool {
        playableEntry(for: playlist) != nil
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func quitApplication() {
        NSApp.terminate(nil)
    }
}

private struct LibraryDashboardView: View {
    let playlists: [PlaylistRecord]
    let selectedPlaylistID: UUID?
    let playlistError: String?
    let onSelectPlaylist: (UUID) -> Void
    let onCreatePlaylist: () -> Void
    let onPlayNow: (PlaylistRecord) -> Void
    let onDeletePlaylist: (UUID) -> Void
    let previewTextProvider: (PlaylistRecord) -> String
    let canPlayProvider: (PlaylistRecord) -> Bool

    var body: some View {
        GeometryReader { proxy in
            let showsSidePanel = proxy.size.width >= 1180

            Group {
                if showsSidePanel {
                    HStack(spacing: 0) {
                        librarySurface
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Divider()
                            .padding(.vertical, 8)

                        playlistsPanel
                            .frame(width: 360)
                            .frame(maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        librarySurface
                            .frame(maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)

                        Divider()
                            .padding(.vertical, 8)

                        playlistsPanel
                            .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var librarySurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Wallpaper Library")
                .font(.title2.weight(.semibold))
            Text("Preview the current desktop, import new wallpapers, and apply changes immediately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            WallpaperLibraryView(layoutMode: .fullDashboard)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.trailing, 24)
    }

    private var playlistsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Playlists")
                        .font(.title3.weight(.semibold))
                    Text("Build rotation sets for focused moods, displays, and schedules.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    onCreatePlaylist()
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            HStack {
                Label("\(playlists.count) total", systemImage: "music.note.list")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let playlistError {
                Text(playlistError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if playlists.isEmpty {
                EmptyPlaylistPlaceholder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CompactPlaylistGrid(
                    playlists: playlists,
                    selectedPlaylistID: selectedPlaylistID,
                    onSelectPlaylist: onSelectPlaylist,
                    onPlayNow: onPlayNow,
                    onDelete: onDeletePlaylist,
                    previewTextProvider: previewTextProvider,
                    canPlayProvider: canPlayProvider
                )
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 6)
    }
}

private struct EmptyPlaylistPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No Playlists Yet")
                .font(.headline)
            Text("Create a playlist to start scheduling rotations and applying curated wallpaper sets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
