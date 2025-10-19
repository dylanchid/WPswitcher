import AppKit
import CoreData
import Foundation
import os.log

final class CoreDataWallpaperService: WallpaperService {
    private let persistence: PersistenceController
    private let playlistStore: PlaylistStore
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.example.WPswitcher", category: "WallpaperService")

    private let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp"]

    init(
        persistence: PersistenceController,
        playlistStore: PlaylistStore,
        fileManager: FileManager = .default
    ) {
        self.persistence = persistence
        self.playlistStore = playlistStore
        self.fileManager = fileManager
    }

    func advanceToNextWallpaper() {
        logger.log("advanceToNextWallpaper invoked – not yet implemented")
    }

    @discardableResult
    func apply(entry: PlaylistEntryRecord, from playlist: PlaylistRecord) -> Bool {
        let screens = NSScreen.screens
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
                logger.log(
                    "Falling back to default entry wallpaper for playlist \(playlist.name, privacy: .public) on all screens"
                )
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

    func toggleRotation() {
        logger.log("toggleRotation invoked – not yet implemented")
    }

    func fetchLibrary() throws -> [WallpaperRecord] {
        let context = persistence.viewContext
        var records: [WallpaperRecord] = []
        var capturedError: Error?

        context.performAndWait {
            do {
                let request = WallpaperEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
                records = try context.fetch(request).map { $0.toRecord() }
            } catch {
                capturedError = error
            }
        }

        if let capturedError {
            throw capturedError
        }

        return records
    }

    @discardableResult
    func importWallpapers(from urls: [URL]) throws -> [WallpaperRecord] {
        let resolvedFiles = collectImageFiles(from: urls)
        guard !resolvedFiles.isEmpty else { return [] }

        var imported: [WallpaperRecord] = []
        var errors: [Error] = []

        for fileURL in resolvedFiles {
            do {
                let bookmark = try createBookmark(for: fileURL)
                let draft = WallpaperDraft(url: fileURL, displayName: fileURL.lastPathComponent, bookmarkData: bookmark)
                let record = try playlistStore.upsertWallpaper(draft)
                imported.append(record)
            } catch {
                logger.error("Failed to import wallpaper at \(fileURL, privacy: .public): \(error.localizedDescription, privacy: .public)")
                errors.append(error)
            }
        }

        if let error = errors.first {
            throw error
        }

        return imported
    }

    func deleteWallpaper(id: UUID) throws {
        let context = persistence.viewContext
        var capturedError: Error?

        context.performAndWait {
            let request = WallpaperEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                if let entity = try context.fetch(request).first {
                    context.delete(entity)
                    try context.save()
                }
            } catch {
                capturedError = error
            }
        }

        if let capturedError {
            throw capturedError
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

    private func isSupportedImage(_ url: URL) -> Bool {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return false }
        return true
    }

    private func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
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

    private func wallpaper(for entry: PlaylistEntryRecord, preferDark: Bool) -> WallpaperRecord? {
        if preferDark {
            return entry.darkWallpaper ?? entry.lightWallpaper
        }
        return entry.lightWallpaper ?? entry.darkWallpaper
    }

    private func wallpaper(for assignment: DisplayAssignmentRecord, preferDark: Bool) -> WallpaperRecord? {
        if preferDark {
            return assignment.darkWallpaper ?? assignment.lightWallpaper
        }
        return assignment.lightWallpaper ?? assignment.darkWallpaper
    }

    private func apply(wallpaper: WallpaperRecord, to screens: [NSScreen], playlistName: String) -> Bool {
        screens.reduce(false) { partialResult, screen in
            apply(wallpaper: wallpaper, to: screen, playlistName: playlistName) || partialResult
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
