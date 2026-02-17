import AppKit
import CoreData
import Foundation
import os.log
import UniformTypeIdentifiers

final class CoreDataWallpaperService: WallpaperService {
    private let persistence: PersistenceController
    private let playlistStore: PlaylistStore
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.example.WPswitcher", category: "WallpaperService")

    init(
        persistence: PersistenceController,
        playlistStore: PlaylistStore,
        fileManager: FileManager = .default
    ) {
        self.persistence = persistence
        self.playlistStore = playlistStore
        self.fileManager = fileManager
    }

    @discardableResult
    func apply(entry: PlaylistEntryRecord, from playlist: PlaylistRecord) -> Bool {
        let screens = getScreens()
        guard !screens.isEmpty else {
            logger.error("No screens available to apply wallpaper for playlist \(playlist.name, privacy: .public)")
            return false
        }

        let preferDark = isDarkAppearanceActive()
        let defaultWallpaper = wallpaper(for: entry, preferDark: preferDark)

        var appliedAny = false

        switch playlist.multiDisplayPolicy {
        case .mirror:
            guard let wallpaper = defaultWallpaper else {
                logger.warning(
                    "Playlist \(playlist.name, privacy: .public) entry \(entry.id.uuidString, privacy: .public) has no wallpaper for mirror policy"
                )
                return false
            }
            appliedAny = apply(wallpaper: wallpaper, to: screens, playlistName: playlist.name)
        case .perDisplay:
            let assignments = Dictionary(uniqueKeysWithValues: playlist.displayAssignments.map { ($0.displayID, $0) })
            for screen in screens {
                let identifier = displayIdentifier(for: screen)
                let assignmentWallpaper = identifier.flatMap { id in
                    assignments[id].flatMap { wallpaper(for: $0, preferDark: preferDark) }
                }
                guard let wallpaper = assignmentWallpaper ?? defaultWallpaper else {
                    logger.warning(
                        "No wallpaper resolved for screen \(identifier ?? "unknown", privacy: .public) in playlist \(playlist.name, privacy: .public)"
                    )
                    continue
                }

                if apply(wallpaper: wallpaper, to: [screen], playlistName: playlist.name) {
                    appliedAny = true
                }
            }

            if !appliedAny, let fallback = defaultWallpaper {
                appliedAny = apply(wallpaper: fallback, to: screens, playlistName: playlist.name)
            }
        }

        if appliedAny {
            logger.log(
                "Applied playlist \(playlist.name, privacy: .public) entry \(entry.id.uuidString, privacy: .public) to \(screens.count, privacy: .public) screen(s)"
            )
        } else {
            logger.error(
                "Failed to apply playlist \(playlist.name, privacy: .public) entry \(entry.id.uuidString, privacy: .public)"
            )
        }

        return appliedAny
    }

    func fetchLibrary() async throws -> [WallpaperRecord] {
        let context = persistence.newBackgroundContext()
        
        return try await context.perform {
            let request = WallpaperEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).map { $0.toRecord() }
        }
    }

    @discardableResult
    func importWallpapers(from urls: [URL]) async throws -> [WallpaperRecord] {
        let resolvedFiles = collectImageFiles(from: urls)
        guard !resolvedFiles.isEmpty else { 
            throw AppError.wallpaperImportFailed("No valid image files found")
        }

        var imported: [WallpaperRecord] = []
        var errors: [Error] = []

        for fileURL in resolvedFiles {
            do {
                // Validate file before importing
                try validateImageFile(at: fileURL)
                
                let bookmark = try createBookmark(for: fileURL)
                let draft = WallpaperDraft(url: fileURL, displayName: fileURL.lastPathComponent, bookmarkData: bookmark)
                let record = try await playlistStore.upsertWallpaper(draft)
                imported.append(record)
            } catch {
                logger.error("Failed to import wallpaper at \(fileURL, privacy: .public): \(error.localizedDescription, privacy: .public)")
                errors.append(error)
            }
        }

        if !errors.isEmpty && imported.isEmpty {
            // If all imports failed, throw the first error
            throw errors.first!
        }

        return imported
    }

    private func validateImageFile(at url: URL) throws {
        // Check file existence
        guard fileManager.fileExists(atPath: url.path) else {
            throw AppError.fileAccessDenied(url.path)
        }

        // Check file size (prevent importing extremely large files)
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw AppError.invalidImageData(url.lastPathComponent)
        }
        
        let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB limit
        guard fileSize <= maxFileSize else {
            throw AppError.wallpaperImportFailed("File too large: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
        }

        // Validate image can be loaded
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw AppError.invalidImageData(url.lastPathComponent)
        }

        // Check image dimensions
        guard let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as String] as? Int,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as String] as? Int else {
            throw AppError.invalidImageData(url.lastPathComponent)
        }

        // Minimum resolution check (at least 1x1)
        guard pixelWidth >= 1 && pixelHeight >= 1 else {
            throw AppError.wallpaperImportFailed("Image too small: \(pixelWidth)x\(pixelHeight). Minimum size is 1x1.")
        }

        // Maximum resolution check (prevent extremely large images)
        let maxDimension = 16384 // macOS wallpaper limit
        guard pixelWidth <= maxDimension && pixelHeight <= maxDimension else {
            throw AppError.wallpaperImportFailed("Image too large: \(pixelWidth)x\(pixelHeight). Maximum size is \(maxDimension)x\(maxDimension).")
        }
    }

    func deleteWallpaper(id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        
        try await context.perform {
            let request = WallpaperEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }

    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution {
        if let bookmark = wallpaper.bookmarkData {
            do {
                var stale = false
                let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
                let accessGranted = resolvedURL.startAccessingSecurityScopedResource()
                if accessGranted {
                    guard fileManager.fileExists(atPath: resolvedURL.path) else {
                        resolvedURL.stopAccessingSecurityScopedResource()
                        return .missing
                    }
                    if stale {
                        refreshBookmark(for: wallpaper.id, using: resolvedURL)
                    }
                    return .available(ScopedWallpaperURL(url: resolvedURL) {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    })
                }
            } catch {
                logger.error("Failed to resolve bookmark for wallpaper \(wallpaper.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if fileManager.fileExists(atPath: wallpaper.url.path) {
            return .available(ScopedWallpaperURL(url: wallpaper.url, stopAccessing: {}))
        }

        return .missing
    }

    // MARK: - Helpers

    private func collectImageFiles(from urls: [URL]) -> [URL] {
        var collected: OrderedSet<URL> = []

        for url in urls {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let needsStop = url.startAccessingSecurityScopedResource()
                defer {
                    if needsStop {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if isSupportedImage(fileURL) {
                            collected.append(fileURL)
                        }
                    }
                }
            } else if isSupportedImage(url) {
                collected.append(url)
            }
        }

        return Array(collected)
    }

    private let supportedExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"]

    private func isSupportedImage(_ url: URL) -> Bool {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return false }
        return true
    }

    private func createBookmark(for url: URL) throws -> Data {
        do {
            // Try creating a security-scoped bookmark first (for production use)
            return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            // Fall back to basic bookmark if security scope fails (e.g., in tests)
            return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
    }

    private func refreshBookmark(for id: UUID, using url: URL) {
        do {
            let data = try createBookmark(for: url)
            let context = persistence.viewContext
            context.perform {
                let request = WallpaperEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                if let entity = try? context.fetch(request).first {
                    entity.bookmarkData = data
                    try? context.save()
                }
            }
        } catch {
            logger.error("Failed to refresh bookmark for wallpaper \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func getScreens() -> [NSScreen] {
        if Thread.isMainThread {
            return NSScreen.screens
        } else {
            return DispatchQueue.main.sync { NSScreen.screens }
        }
    }

    private func apply(wallpaper: WallpaperRecord, to screens: [NSScreen], playlistName: String) -> Bool {
        var appliedAny = false
        for screen in screens {
            if apply(wallpaper: wallpaper, to: screen, playlistName: playlistName) {
                appliedAny = true
            }
        }
        return appliedAny
    }

    private func wallpaper(for entry: PlaylistEntryRecord, preferDark: Bool) -> WallpaperRecord? {
        if preferDark {
            return entry.darkWallpaper ?? entry.lightWallpaper
        } else {
            return entry.lightWallpaper ?? entry.darkWallpaper
        }
    }

    private func wallpaper(for assignment: DisplayAssignmentRecord, preferDark: Bool) -> WallpaperRecord? {
        if preferDark {
            return assignment.darkWallpaper ?? assignment.lightWallpaper
        } else {
            return assignment.lightWallpaper ?? assignment.darkWallpaper
        }
    }

    private func apply(wallpaper: WallpaperRecord, to screen: NSScreen, playlistName: String) -> Bool {
        switch resolveAccess(for: wallpaper) {
        case .missing:
            logger.error(
                "Wallpaper \(wallpaper.displayName, privacy: .public) missing when applying playlist \(playlistName, privacy: .public)"
            )
            return false
        case .available(let scoped):
            defer { scoped.stopAccessing() }
            let workspace = NSWorkspace.shared
            let options = workspace.desktopImageOptions(for: screen) ?? [:]
            do {
                try workspace.setDesktopImageURL(scoped.url, for: screen, options: options)
                logger.log(
                    "Set wallpaper \(wallpaper.displayName, privacy: .public) on screen \(self.displayIdentifier(for: screen) ?? "unknown", privacy: .public) for playlist \(playlistName, privacy: .public)"
                )
                return true
            } catch {
                logger.error(
                    "Failed to set wallpaper \(wallpaper.displayName, privacy: .public) on screen \(self.displayIdentifier(for: screen) ?? "unknown", privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return false
            }
        }
    }

    private func displayIdentifier(for screen: NSScreen) -> String? {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.stringValue
        }

        if #available(macOS 10.15, *) {
            return screen.localizedName
        }

        return nil
    }

    private func isDarkAppearanceActive() -> Bool {
        guard #available(macOS 10.14, *) else { return false }
        var isDark = false
        let evaluate = {
            let match = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            isDark = (match == .darkAqua)
        }
        if Thread.isMainThread {
            evaluate()
        } else {
            DispatchQueue.main.sync(execute: evaluate)
        }
        return isDark
    }
}

// OrderedSet helper for deterministic import ordering without duplicates
private struct OrderedSet<Element: Hashable>: ExpressibleByArrayLiteral, Sequence {
    private var array: [Element] = []
    private var set: Set<Element> = []

    init() {}

    init(arrayLiteral elements: Element...) {
        elements.forEach { append($0) }
    }

    mutating func append(_ element: Element) {
        guard !set.contains(element) else { return }
        set.insert(element)
        array.append(element)
    }

    func makeIterator() -> IndexingIterator<[Element]> {
        array.makeIterator()
    }

    var values: [Element] { array }
}
