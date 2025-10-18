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
                if playlists.isEmpty {
                    Label("No playlists yet", systemImage: "music.note.list")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: MainDestination.playlist(playlist.id)) {
                            Label(playlist.name, systemImage: "music.note.list")
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
            WallpaperBrowserView()
                .environmentObject(services)
        case .playlist(let id):
            if let playlist = playlists.first(where: { $0.id == id }) {
                PlaylistDetailView(playlist: playlist)
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

private struct PlaylistDetailView: View {
    let playlist: PlaylistRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if playlist.wallpapers.isEmpty {
                    MissingSelectionPlaceholder(
                        title: "No Wallpapers",
                        message: "Import wallpapers into the library, then add them to this playlist."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallpapers")
                            .font(.headline)
                        ForEach(playlist.wallpapers) { wallpaper in
                            HStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wallpaper.displayName)
                                        .font(.body)
                                    Text(wallpaper.url.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(playlist.name)
                .font(.largeTitle)
                .bold()
            Text("Rotates every \(playlist.intervalMinutes) minutes")
                .font(.callout)
                .foregroundColor(.secondary)
            Divider()
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

#Preview {
    MainWindowView()
        .environmentObject(ServiceRegistry.preview)
}
