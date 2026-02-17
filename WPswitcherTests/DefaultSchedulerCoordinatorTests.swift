import XCTest
@testable import WPswitcher

final class DefaultSchedulerCoordinatorTests: XCTestCase {
    func testCoordinatorUsesSingleDeterministicActivePlaylist() async throws {
        let earlyDate = Date(timeIntervalSince1970: 100)
        let lateDate = Date(timeIntervalSince1970: 200)
        let earlyPlaylist = makePlaylist(name: "Early", createdAt: earlyDate)
        let latePlaylist = makePlaylist(name: "Late", createdAt: lateDate)
        let playlistStore = MockPlaylistStore(playlists: [latePlaylist, earlyPlaylist])
        let wallpaperService = MockWallpaperService()
        let notificationCenter = NotificationCenter()

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: NotificationCenter(),
            playlistNotificationCenter: notificationCenter,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.queue")
        )

        coordinator.start()
        await waitUntil("active playlist selection") {
            coordinator.activePlaylistID == earlyPlaylist.id
        }

        coordinator.advance()
        await waitUntil("manual advance application") {
            wallpaperService.appliedPlaylists.count == 1
        }

        XCTAssertEqual(wallpaperService.appliedPlaylists, [earlyPlaylist.id])
        coordinator.pause()
    }

    func testWallpaperLibraryNotificationTriggersRebuild() async throws {
        let playlistStore = MockPlaylistStore(playlists: [makePlaylist(name: "Only", createdAt: Date(timeIntervalSince1970: 100))])
        let wallpaperService = MockWallpaperService()
        let notificationCenter = NotificationCenter()

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: NotificationCenter(),
            playlistNotificationCenter: notificationCenter,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.rebuildQueue")
        )

        coordinator.start()
        await waitUntil("initial schedule rebuild") {
            playlistStore.currentFetchCount >= 1
        }

        notificationCenter.post(name: .wallpaperLibraryDidChange, object: nil)
        await waitUntil("wallpaper notification rebuild") {
            playlistStore.currentFetchCount >= 2
        }

        coordinator.pause()
    }

    private func makePlaylist(name: String, createdAt: Date) -> PlaylistRecord {
        let wallpaper = WallpaperRecord(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/\(name).jpg"),
            displayName: "\(name).jpg",
            createdAt: createdAt,
            bookmarkData: nil
        )
        let entry = PlaylistEntryRecord(
            id: UUID(),
            order: 0,
            lightWallpaper: wallpaper,
            darkWallpaper: nil
        )
        return PlaylistRecord(
            id: UUID(),
            name: name,
            intervalMinutes: 15,
            createdAt: createdAt,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [entry],
            displayAssignments: []
        )
    }

    private func waitUntil(
        _ label: String,
        timeout: TimeInterval = 1.0,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Timed out waiting for \(label)")
    }
}

private enum MockStoreError: Error {
    case unexpectedCall
}

private final class MockPlaylistStore: PlaylistStore {
    private let lock = NSLock()
    private(set) var playlists: [PlaylistRecord]
    private(set) var fetchCount = 0

    init(playlists: [PlaylistRecord]) {
        self.playlists = playlists
    }

    var currentFetchCount: Int {
        lock.withLock { fetchCount }
    }

    @discardableResult
    func createPlaylist(_ draft: PlaylistDraft) async throws -> PlaylistRecord {
        XCTFail("Unexpected createPlaylist call in mock")
        throw MockStoreError.unexpectedCall
    }

    func fetchPlaylists() async throws -> [PlaylistRecord] {
        lock.withLock {
            fetchCount += 1
        }
        return lock.withLock { playlists }
    }

    func fetchPlaylist(id: UUID) async throws -> PlaylistRecord? {
        lock.withLock { playlists.first(where: { $0.id == id }) }
    }

    @discardableResult
    func updatePlaylist(_ draft: PlaylistDraft) async throws -> PlaylistRecord {
        XCTFail("Unexpected updatePlaylist call in mock")
        throw MockStoreError.unexpectedCall
    }

    func deletePlaylist(id: UUID) async throws {
        XCTFail("Unexpected deletePlaylist call in mock")
        throw MockStoreError.unexpectedCall
    }

    @discardableResult
    func upsertWallpaper(_ draft: WallpaperDraft) async throws -> WallpaperRecord {
        XCTFail("Unexpected upsertWallpaper call in mock")
        throw MockStoreError.unexpectedCall
    }
}

private final class MockWallpaperService: WallpaperService {
    private let lock = NSLock()
    private(set) var appliedPlaylists: [UUID] = []

    @discardableResult
    func apply(entry: PlaylistEntryRecord, from playlist: PlaylistRecord) -> Bool {
        lock.withLock {
            appliedPlaylists.append(playlist.id)
        }
        return true
    }

    func fetchLibrary() async throws -> [WallpaperRecord] {
        []
    }

    @discardableResult
    func importWallpapers(from urls: [URL]) async throws -> [WallpaperRecord] {
        []
    }

    func deleteWallpaper(id: UUID) async throws {}

    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution {
        .missing
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
