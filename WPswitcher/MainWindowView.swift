import AppKit
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var selection: MainDestination? = .library
    @State private var playlists: [PlaylistRecord] = []
    @State private var playlistError: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .frame(minWidth: 900, minHeight: 580)
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
                .environmentObject(services)
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
        do {
            playlists = try services.playlistStore.fetchPlaylists()
            playlistError = nil
            ensureValidSelection()
        } catch {
            playlists = []
            playlistError = error.localizedDescription
        }
    }

    private func ensureValidSelection() {
        if case let .playlist(id) = selection,
           !playlists.contains(where: { $0.id == id }) {
            selection = .library
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

        do {
            let record = try services.playlistStore.createPlaylist(draft)
            handlePlaylistSaved(record)
            selection = .playlist(record.id)
        } catch {
            playlistError = error.localizedDescription
        }
    }

    private func deletePlaylist(_ id: UUID) {
        do {
            try services.playlistStore.deletePlaylist(id: id)
            playlists.removeAll { $0.id == id }
            playlistError = nil
            ensureValidSelection()
        } catch {
            playlistError = error.localizedDescription
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
                viewModel.applyUpdatedRecord(newValue)
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


struct WallpaperLibraryView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var wallpapers: [WallpaperRecord] = []
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var previewSelection: PreviewSelection = .currentDesktop
    @State private var currentWallpaperURL: URL?
    @State private var currentWallpaperImage: NSImage?
    @State private var isLoadingCurrentWallpaper = false
    @State private var isRotationRunning = false

    private var selectedWallpaper: WallpaperRecord? {
        guard case let .wallpaper(id) = previewSelection else { return nil }
        return wallpapers.first(where: { $0.id == id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                previewSection
                filmstripSection
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear(perform: initialize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wallpaper Library")
                        .font(.largeTitle)
                        .bold()
                    Text("Browse, preview, and manage the wallpapers stored in WPswitcher.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
                controlButtons
            }
            Divider()
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: advanceWallpaper) {
                Label("Next Wallpaper", systemImage: "arrow.right.circle")
            }
            Button(action: toggleRotation) {
                Label(
                    isRotationRunning ? "Pause Rotation" : "Resume Rotation",
                    systemImage: isRotationRunning ? "pause.circle" : "play.circle"
                )
            }
            Button(action: importWallpapers) {
                Label("Import…", systemImage: "square.and.arrow.down")
            }
            .disabled(isImporting)
        }
        .controlSize(.large)
        .buttonStyle(.bordered)
    }

    private var previewSection: some View {
        previewContent
            .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 320)
    }

    private var previewContent: some View {
        Group {
            switch previewSelection {
            case .currentDesktop:
                CurrentDesktopPreview(image: currentWallpaperImage, isLoading: isLoadingCurrentWallpaper)
            case .wallpaper:
                if let record = selectedWallpaper {
                    WallpaperPreview(record: record)
                } else {
                    MissingPreviewPlaceholder(message: "Select a wallpaper to see it here.")
                }
            }
        }
    }

    private var filmstripSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    LibraryFilmstripItem(
                        title: "Current Desktop",
                        isSelected: previewSelection == .currentDesktop,
                        action: { previewSelection = .currentDesktop }
                    ) {
                        CurrentDesktopThumbnail(image: currentWallpaperImage, isLoading: isLoadingCurrentWallpaper)
                    }

                    ForEach(wallpapers) { record in
                        LibraryFilmstripItem(
                            title: record.displayName,
                            isSelected: previewSelection == .wallpaper(record.id),
                            action: { previewSelection = .wallpaper(record.id) }
                        ) {
                            WallpaperFilmstripThumbnail(record: record)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(record)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }

                    LibraryFilmstripItem(
                        title: "",
                        isSelected: false,
                        action: importWallpapers
                    ) {
                        AddWallpaperThumbnail()
                    }
                    .disabled(isImporting)
                    .accessibilityLabel("Add Wallpapers")
                }
                .padding(.vertical, 4)
            }

            if wallpapers.isEmpty {
                Text("Import wallpapers to start building your library.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func initialize() {
        isRotationRunning = services.schedulerCoordinator.isRunning
        loadCurrentDesktop()
        loadLibrary()
    }

    private func loadLibrary() {
        do {
            let records = try services.wallpaperService.fetchLibrary()
            wallpapers = records
            errorMessage = nil
            alignSelectionWithLibrary()
            if case .currentDesktop = previewSelection {
                alignSelectionWithCurrentDesktop()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importWallpapers() {
        let panel = NSOpenPanel()
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            isImporting = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let imported = try services.wallpaperService.importWallpapers(from: urls)
                    let records = try services.wallpaperService.fetchLibrary()
                    DispatchQueue.main.async {
                        self.wallpapers = records
                        self.errorMessage = nil
                        self.isImporting = false
                        if let last = imported.last {
                            self.previewSelection = .wallpaper(last.id)
                        } else {
                            self.alignSelectionWithLibrary()
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isImporting = false
                    }
                }
            }
        }
    }

    private func advanceWallpaper() {
        services.wallpaperService.advanceToNextWallpaper()
        loadCurrentDesktop()
    }

    private func toggleRotation() {
        services.schedulerCoordinator.toggleRotation()
        services.wallpaperService.toggleRotation()
        isRotationRunning = services.schedulerCoordinator.isRunning
    }

    private func delete(_ record: WallpaperRecord) {
        do {
            try services.wallpaperService.deleteWallpaper(id: record.id)
            if previewSelection == .wallpaper(record.id) {
                previewSelection = .currentDesktop
            }
            loadLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCurrentDesktop() {
        guard !isLoadingCurrentWallpaper else { return }
        isLoadingCurrentWallpaper = true

        DispatchQueue.global(qos: .userInitiated).async {
            let workspace = NSWorkspace.shared
            let screen = NSScreen.main ?? NSScreen.screens.first
            let desktopURL = screen.flatMap { workspace.desktopImageURL(for: $0) }
            let desktopImage = desktopURL.flatMap { NSImage(contentsOf: $0) }

            DispatchQueue.main.async {
                self.currentWallpaperURL = desktopURL
                self.currentWallpaperImage = desktopImage
                self.isLoadingCurrentWallpaper = false
                if case .currentDesktop = self.previewSelection {
                    self.alignSelectionWithCurrentDesktop()
                }
            }
        }
    }

    private func alignSelectionWithLibrary() {
        if case let .wallpaper(id) = previewSelection,
           !wallpapers.contains(where: { $0.id == id }) {
            previewSelection = .currentDesktop
        }
    }

    private func alignSelectionWithCurrentDesktop() {
        guard let currentURL = currentWallpaperURL else { return }
        guard case .currentDesktop = previewSelection else { return }

        if let match = wallpapers.first(where: { recordMatches($0, currentURL: currentURL) }) {
            previewSelection = .wallpaper(match.id)
        }
    }

    private func recordMatches(_ record: WallpaperRecord, currentURL: URL) -> Bool {
        record.url.standardizedFileURL.path == currentURL.standardizedFileURL.path
    }
}

private enum PreviewSelection: Equatable {
    case currentDesktop
    case wallpaper(UUID)
}

private struct MissingPreviewPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct CurrentDesktopPreview: View {
    let image: NSImage?
    let isLoading: Bool

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else if isLoading {
                ProgressView()
                    .controlSize(.large)
            } else {
                MissingPreviewPlaceholder(message: "Unable to load the current desktop wallpaper.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WallpaperPreview: View {
    let record: WallpaperRecord
    @EnvironmentObject private var services: ServiceRegistry
    @State private var image: NSImage?
    @State private var isMissing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            } else if isMissing {
                MissingPreviewPlaceholder(message: "This file can no longer be accessed.")
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            if isMissing {
                Label("Missing", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: loadImage)
        .onChange(of: record.id) { _ in
            image = nil
            isMissing = false
            loadImage()
        }
    }

    private func loadImage() {
        guard image == nil && !isMissing else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            switch services.wallpaperService.resolveAccess(for: record) {
            case .available(let handle):
                defer { handle.stopAccessing() }
                if let nsImage = NSImage(contentsOf: handle.url) {
                    DispatchQueue.main.async {
                        self.image = nsImage
                        self.isMissing = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isMissing = true
                    }
                }
            case .missing:
                DispatchQueue.main.async {
                    self.isMissing = true
                }
            }
        }
    }
}

private struct LibraryFilmstripItem<Thumbnail: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var thumbnail: () -> Thumbnail

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                    thumbnail()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(width: 140, height: 88)

                Text(title)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .frame(width: 140)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AddWallpaperThumbnail: View {
    var body: some View {
        ZStack {
            Color.clear
            Image(systemName: "plus")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CurrentDesktopThumbnail: View {
    let image: NSImage?
    let isLoading: Bool

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if isLoading {
                ProgressView()
            } else {
                ThumbnailPlaceholder()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct WallpaperFilmstripThumbnail: View {
    let record: WallpaperRecord
    @EnvironmentObject private var services: ServiceRegistry
    @State private var image: NSImage?
    @State private var isMissing = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else if isMissing {
                ThumbnailPlaceholder(systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear(perform: loadImage)
        .onChange(of: record.id) { _ in
            image = nil
            isMissing = false
            loadImage()
        }
    }

    private func loadImage() {
        guard image == nil && !isMissing else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            switch services.wallpaperService.resolveAccess(for: record) {
            case .available(let handle):
                defer { handle.stopAccessing() }
                if let nsImage = NSImage(contentsOf: handle.url) {
                    DispatchQueue.main.async {
                        self.image = nsImage
                        self.isMissing = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isMissing = true
                    }
                }
            case .missing:
                DispatchQueue.main.async {
                    self.isMissing = true
                }
            }
        }
    }
}

private struct ThumbnailPlaceholder: View {
    var systemImage: String = "photo"
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    WallpaperLibraryView()
        .environmentObject(ServiceRegistry.preview)
        .frame(width: 860, height: 560)
}

#Preview {
    MainWindowView()
        .environmentObject(ServiceRegistry.preview)
}
