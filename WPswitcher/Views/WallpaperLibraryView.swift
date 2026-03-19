import AppKit
import SwiftUI

struct WallpaperLibraryView: View {
    @EnvironmentObject private var services: ServiceRegistry
    @EnvironmentObject private var schedulerState: SchedulerViewState
    @State private var wallpapers: [WallpaperRecord] = []
    @State private var isImporting = false
    @State private var previewSelection: PreviewSelection = .currentDesktop
    @State private var currentWallpaperURL: URL?
    @State private var currentWallpaperImage: NSImage?
    @State private var isLoadingCurrentWallpaper = false

    private var selectedWallpaper: WallpaperRecord? {
        guard case let .wallpaper(id) = previewSelection else { return nil }
        return wallpapers.first(where: { $0.id == id })
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 760

            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                        mainContentSection(isCompact: isCompact)
                        filmstripSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color.clear)
                .onAppear(perform: initialize)
                .onChange(of: schedulerState.rotationEventCount) { _ in
                    loadCurrentDesktop()
                }

                ErrorBanner(errorManager: services.errorManager)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedWallpaper?.displayName ?? "Current Desktop")
                    .font(.title3.weight(.semibold))
                Text(selectionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                actionButton(
                    title: "Import",
                    systemImage: "square.and.arrow.down",
                    style: .prominent,
                    action: importWallpapers
                )
                .disabled(isImporting)

                actionButton(
                    title: schedulerState.isRunning ? "Pause Rotation" : "Resume Rotation",
                    systemImage: schedulerState.isRunning ? "pause.fill" : "play.fill",
                    style: .standard,
                    action: toggleRotation
                )

                actionButton(
                    title: "Next Wallpaper",
                    systemImage: "arrow.right.circle",
                    style: .standard,
                    action: advanceWallpaper
                )
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: advanceWallpaper) {
                Label("Next Wallpaper", systemImage: "arrow.right.circle")
            }
            .help("Apply the next wallpaper in rotation.")

            Button(action: toggleRotation) {
                Label(
                    schedulerState.isRunning ? "Pause Rotation" : "Resume Rotation",
                    systemImage: schedulerState.isRunning ? "pause.circle" : "play.circle"
                )
            }
            .help(schedulerState.isRunning ? "Pause automatic rotation." : "Resume automatic rotation.")

            Button(action: importWallpapers) {
                Label("Import Wallpapers", systemImage: "square.and.arrow.down")
            }
            .help("Import one or more images into the library.")
            .disabled(isImporting)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private func mainContentSection(isCompact: Bool) -> some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 10) {
                    previewCard
                        .frame(height: 260)

                    fileInfoSection
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    previewCard
                        .frame(minHeight: 320, maxHeight: 420, alignment: .topLeading)
                        .frame(minWidth: 420, maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 8) {
                        fileInfoSection
                    }
                    .frame(width: 280, alignment: .topLeading)

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var previewCard: some View {
        previewContent
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var previewContent: some View {
        ZStack {
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
        .id(previewSelection)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Details")
                .font(.headline)

            if let info = selectedFileInfo {
                FileInfoRow(label: "File", value: info.name, emphasis: .high)
                if let createdAt = info.createdAt {
                    FileInfoRow(label: "Created", value: Self.fileInfoDateFormatter.string(from: createdAt))
                }
                if let sizeBytes = info.sizeBytes {
                    FileInfoRow(label: "Size", value: Self.byteFormatter.string(fromByteCount: sizeBytes))
                }
                if let fileType = info.fileType {
                    FileInfoRow(label: "Type", value: fileType)
                }
                FileInfoRow(label: "Location", value: info.location)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Library")
                    .font(.headline)
                Spacer()
                Text("\(wallpapers.count) item\(wallpapers.count == 1 ? "" : "s")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    LibraryFilmstripItem(
                        title: "Current Desktop",
                        isSelected: previewSelection == .currentDesktop,
                        action: selectCurrentDesktop
                    ) {
                        CurrentDesktopThumbnail(image: currentWallpaperImage, isLoading: isLoadingCurrentWallpaper)
                    }

                    ForEach(wallpapers) { record in
                        LibraryFilmstripItem(
                            title: record.displayName,
                            isSelected: previewSelection == .wallpaper(record.id),
                            action: { selectWallpaper(record) }
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
                        title: "Add",
                        isSelected: false,
                        style: .add,
                        action: importWallpapers
                    ) {
                        AddWallpaperThumbnail()
                    }
                    .disabled(isImporting)
                    .accessibilityLabel("Add Wallpapers")
                }
                .padding(.vertical, 2)
            }
            .frame(height: 108)

            if wallpapers.isEmpty {
                Text("Import wallpapers to start building your library.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 6)
    }

    private func initialize() {
        loadLibrary()
        loadCurrentDesktop()
        schedulerState.refresh(from: services.schedulerCoordinator)
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
                            self.selectWallpaper(last)
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
    }

    private func selectCurrentDesktop() {
        withAnimation(.easeInOut(duration: 0.2)) {
            previewSelection = .currentDesktop
        }
        loadCurrentDesktop()
    }

    private func selectWallpaper(_ record: WallpaperRecord) {
        withAnimation(.easeInOut(duration: 0.2)) {
            previewSelection = .wallpaper(record.id)
        }

        let previewEntry = PlaylistEntryRecord(
            id: UUID(),
            order: 0,
            lightWallpaper: record,
            darkWallpaper: nil
        )
        let previewPlaylist = PlaylistRecord(
            id: UUID(),
            name: "Library Preview",
            intervalMinutes: 0,
            createdAt: Date(),
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [previewEntry],
            displayAssignments: []
        )

        let applied = services.wallpaperService.apply(entry: previewEntry, from: previewPlaylist)
        if applied {
            loadCurrentDesktop()
        } else {
            services.errorManager.handle(
                AppError.wallpaperApplicationFailed("Unable to set \(record.displayName)."),
                context: "applying wallpaper from library"
            )
        }
    }

    private func toggleRotation() {
        services.schedulerCoordinator.toggleRotation()
    }

    private func delete(_ record: WallpaperRecord) {
        Task {
            do {
                try await services.wallpaperService.deleteWallpaper(id: record.id)
                await MainActor.run {
                    if previewSelection == .wallpaper(record.id) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            previewSelection = .currentDesktop
                        }
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

    private var selectionSummary: String {
        switch previewSelection {
        case .currentDesktop:
            return "Previewing the wallpaper currently applied to your desktop."
        case .wallpaper:
            return "Review metadata, verify the asset, and apply it instantly."
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        style: HeaderActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            switch style {
            case .prominent:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

            case .standard:
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}

private enum HeaderActionStyle {
    case standard
    case prominent
}

private enum PreviewSelection: Hashable {
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
    var emphasis: Emphasis = .standard

    enum Emphasis {
        case standard
        case high
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(emphasis == .high ? .title3.weight(.semibold) : .body)
                .lineLimit(emphasis == .high ? 2 : 3)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    enum Style {
        case regular
        case add
    }

    let title: String
    let isSelected: Bool
    var style: Style = .regular
    let action: () -> Void
    @ViewBuilder var thumbnail: () -> Thumbnail

    private var thumbnailWidth: CGFloat {
        style == .add ? 74 : 88
    }

    private var thumbnailHeight: CGFloat {
        style == .add ? 50 : 56
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.18), lineWidth: isSelected ? 2 : 1)
                        )
                    thumbnail()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(style == .add ? 0 : 2)
                }
                .frame(width: thumbnailWidth, height: thumbnailHeight)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: thumbnailWidth, maxWidth: thumbnailWidth, alignment: .center)
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
                .font(.system(size: 22, weight: .semibold))
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
