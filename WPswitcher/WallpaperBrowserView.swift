import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WallpaperBrowserView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Text(previewTitle)
                .font(.headline)
            if let subtitle = previewSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            LibraryPreviewContainer {
                previewContent
            }
        }
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
            Text("Library Items")
                .font(.headline)

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

    private var previewTitle: String {
        switch previewSelection {
        case .currentDesktop:
            return "Current Desktop Wallpaper"
        case .wallpaper:
            return selectedWallpaper?.displayName ?? "Wallpaper Preview"
        }
    }

    private var previewSubtitle: String? {
        switch previewSelection {
        case .currentDesktop:
            return currentWallpaperURL?.path
        case .wallpaper:
            return selectedWallpaper?.url.path
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

private struct LibraryPreviewContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 320)
    }
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
    WallpaperBrowserView()
        .environmentObject(ServiceRegistry.preview)
        .frame(width: 860, height: 560)
}
