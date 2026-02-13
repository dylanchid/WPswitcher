import AppKit
import SwiftUI

struct WallpaperLibraryView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @State private var wallpapers: [WallpaperRecord] = []
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
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    previewSection
                    filmstripSection
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear(perform: initialize)
            
            ErrorBanner(errorManager: services.errorManager)
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
        .controlSize(.small)
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                controlButtons
            }
            HStack(alignment: .top, spacing: 16) {
                previewContent
                    .frame(width: 220, height: 150, alignment: .leading)
                fileInfoSection
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Info")
                .font(.subheadline)

            if let info = selectedFileInfo {
                FileInfoRow(label: "File name", value: info.name)
                if let createdAt = info.createdAt {
                    FileInfoRow(label: "Created", value: Self.fileInfoDateFormatter.string(from: createdAt))
                }
                if let sizeBytes = info.sizeBytes {
                    FileInfoRow(label: "Size", value: Self.byteFormatter.string(fromByteCount: sizeBytes))
                }
                if let fileType = info.fileType {
                    FileInfoRow(label: "Type", value: fileType)
                }
            } else {
                Text("Select a wallpaper to see file details.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var selectedFileInfo: FileInfo? {
        switch previewSelection {
        case .currentDesktop:
            return fileInfo(for: currentWallpaperURL, fallbackCreatedAt: nil)
        case .wallpaper:
            guard let record = selectedWallpaper else { return nil }
            return fileInfo(for: record.url, fallbackCreatedAt: record.createdAt)
        }
    }

    private func fileInfo(for url: URL?, fallbackCreatedAt: Date?) -> FileInfo? {
        guard let url else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let createdAt = (attributes?[.creationDate] as? Date) ?? fallbackCreatedAt
        let sizeBytes = (attributes?[.size] as? NSNumber)?.int64Value
        return FileInfo(
            name: url.lastPathComponent,
            createdAt: createdAt,
            sizeBytes: sizeBytes,
            fileType: url.pathExtension.isEmpty ? nil : url.pathExtension.uppercased(),
            location: url.deletingLastPathComponent().path
        )
    }

    private static let fileInfoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private var filmstripSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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
                .padding(.vertical, 2)
            }

            if wallpapers.isEmpty {
                Text("Import wallpapers to start building your library.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func initialize() {
        loadLibrary()
        loadCurrentDesktop()
        updateRotationStatus()
    }

    private func loadLibrary() {
        Task {
            do {
                let records = try await services.wallpaperService.fetchLibrary()
                await MainActor.run {
                    wallpapers = records
                    alignSelectionWithLibrary()
                    if case .currentDesktop = previewSelection {
                        alignSelectionWithCurrentDesktop()
                    }
                }
            } catch {
                await MainActor.run {
                    services.errorManager.handle(error, context: "loading wallpaper library")
                }
            }
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

            Task {
                do {
                    let imported = try await services.wallpaperService.importWallpapers(from: urls)
                    let records = try await services.wallpaperService.fetchLibrary()
                    await MainActor.run {
                        self.wallpapers = records
                        self.isImporting = false
                        if let last = imported.last {
                            self.previewSelection = .wallpaper(last.id)
                        } else {
                            self.alignSelectionWithLibrary()
                        }
                    }
                } catch {
                    await MainActor.run {
                        services.errorManager.handle(error, context: "importing wallpapers")
                        self.isImporting = false
                    }
                }
            }
        }
    }

    private func advanceWallpaper() {
        services.schedulerCoordinator.advance()
        loadCurrentDesktop()
    }

    private func toggleRotation() {
        services.schedulerCoordinator.toggleRotation()
        updateRotationStatus()
    }

    private func updateRotationStatus() {
        isRotationRunning = services.schedulerCoordinator.isRunning
    }

    private func delete(_ record: WallpaperRecord) {
        Task {
            do {
                try await services.wallpaperService.deleteWallpaper(id: record.id)
                await MainActor.run {
                    if previewSelection == .wallpaper(record.id) {
                        previewSelection = .currentDesktop
                    }
                }
                loadLibrary()
            } catch {
                await MainActor.run {
                    services.errorManager.handle(error, context: "deleting wallpaper")
                }
            }
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

private struct FileInfo: Equatable {
    let name: String
    let createdAt: Date?
    let sizeBytes: Int64?
    let fileType: String?
    let location: String
}

private struct FileInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
        }
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
                    .padding(12)
            } else if isLoading {
                ProgressView()
                    .controlSize(.large)
            } else {
                MissingPreviewPlaceholder(message: "Unable to load the current desktop wallpaper.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                    .padding(12)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                .frame(width: 70, height: 44)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .frame(width: 70)
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

#if DEBUG
struct WallpaperLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        WallpaperLibraryView()
            .environmentObject(ServiceRegistry.preview)
            .frame(width: 860, height: 560)
    }
}
#endif
