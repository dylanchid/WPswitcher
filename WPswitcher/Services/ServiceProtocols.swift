import Foundation
import os.log

struct ScopedWallpaperURL {
    let url: URL
    let stopAccessing: () -> Void
}

enum WallpaperResolution {
    case available(ScopedWallpaperURL)
    case missing
}

protocol WallpaperService {
    func advanceToNextWallpaper()
    func toggleRotation()
    func fetchLibrary() throws -> [WallpaperRecord]
    @discardableResult func importWallpapers(from urls: [URL]) throws -> [WallpaperRecord]
    func deleteWallpaper(id: UUID) throws
    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution
}

protocol PlaylistStore {
    @discardableResult func createPlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord
    func fetchPlaylists() throws -> [PlaylistRecord]
    func fetchPlaylist(id: UUID) throws -> PlaylistRecord?
    @discardableResult func updatePlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord
    func deletePlaylist(id: UUID) throws
    @discardableResult func upsertWallpaper(_ draft: WallpaperDraft) throws -> WallpaperRecord
}

protocol SchedulerCoordinator {
    var isRunning: Bool { get }
    func start()
    func pause()
    func toggleRotation()
}

protocol AppearanceObserver {
    func startObserving()
    func stopObserving()
}

enum PlaylistStoreError: Error {
    case playlistNotFound
    case invalidDraft
}

final class DefaultWallpaperService: WallpaperService {
    func advanceToNextWallpaper() {
        os_log("Advance to next wallpaper (stub)")
    }

    func toggleRotation() {
        os_log("Toggle wallpaper rotation (stub)")
    }

    func fetchLibrary() throws -> [WallpaperRecord] {
        os_log("Fetch wallpaper library (stub)")
        return []
    }

    func importWallpapers(from urls: [URL]) throws -> [WallpaperRecord] {
        os_log("Import wallpapers (stub) %{public}@", urls.description)
        return []
    }

    func deleteWallpaper(id: UUID) throws {
        os_log("Delete wallpaper (stub) %{public}@", id.uuidString)
    }

    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution {
        os_log("Resolve access for wallpaper (stub) %{public}@", wallpaper.id.uuidString)
        return .missing
    }
}

final class DefaultSchedulerCoordinator: SchedulerCoordinator {
    private(set) var isRunning = false

    func start() {
        isRunning = true
        os_log("Start scheduler (stub)")
    }

    func pause() {
        isRunning = false
        os_log("Pause scheduler (stub)")
    }

    func toggleRotation() {
        isRunning.toggle()
        os_log("Toggle scheduler rotation (stub), now %{public}@", isRunning ? "running" : "paused")
    }
}

final class DefaultAppearanceObserver: AppearanceObserver {
    func startObserving() {
        os_log("Start appearance observer (stub)")
    }

    func stopObserving() {
        os_log("Stop appearance observer (stub)")
    }
}
