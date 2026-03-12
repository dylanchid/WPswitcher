import XCTest
@testable import WPswitcher

final class DefaultSchedulerCoordinatorTests: XCTestCase {
    private let selectionDefaultsKey = "DefaultSchedulerCoordinatorTests.activePlaylist"

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
            wallpaperService.currentAppliedPlaylists.count == 1
        }

        XCTAssertEqual(wallpaperService.currentAppliedPlaylists, [earlyPlaylist.id])
        coordinator.pause()
    }

    func testCoordinatorRestoresPersistedActivePlaylistSelection() async throws {
        let earlyDate = Date(timeIntervalSince1970: 100)
        let lateDate = Date(timeIntervalSince1970: 200)
        let earlyPlaylist = makePlaylist(name: "Early", createdAt: earlyDate)
        let latePlaylist = makePlaylist(name: "Late", createdAt: lateDate)
        let playlistStore = MockPlaylistStore(playlists: [earlyPlaylist, latePlaylist])
        let wallpaperService = MockWallpaperService()
        let (defaults, suiteName) = makeDefaults()
        defer { clearDefaults(named: suiteName) }

        defaults.set(latePlaylist.id.uuidString, forKey: selectionDefaultsKey)

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: NotificationCenter(),
            playlistNotificationCenter: NotificationCenter(),
            userDefaults: defaults,
            activePlaylistDefaultsKey: selectionDefaultsKey,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.restoreQueue")
        )

        coordinator.start()
        await waitUntil("restored active playlist") {
            coordinator.activePlaylistID == latePlaylist.id
        }
        await waitUntil("restored active playlist schedule") {
            playlistStore.currentFetchCount >= 1
        }

        await waitUntil("manual advance after restored selection") {
            coordinator.advance()
            return wallpaperService.currentAppliedPlaylists.contains(latePlaylist.id)
        }

        let appliedPlaylists = wallpaperService.currentAppliedPlaylists
        XCTAssertFalse(appliedPlaylists.isEmpty)
        XCTAssertTrue(appliedPlaylists.allSatisfy { $0 == latePlaylist.id })
        XCTAssertEqual(appliedPlaylists.last, latePlaylist.id)
        coordinator.pause()
    }

    func testCoordinatorPersistsFallbackSelectionWhenPreferenceMissing() async throws {
        let earlyDate = Date(timeIntervalSince1970: 100)
        let lateDate = Date(timeIntervalSince1970: 200)
        let earlyPlaylist = makePlaylist(name: "Early", createdAt: earlyDate)
        let latePlaylist = makePlaylist(name: "Late", createdAt: lateDate)
        let playlistStore = MockPlaylistStore(playlists: [latePlaylist, earlyPlaylist])
        let wallpaperService = MockWallpaperService()
        let (defaults, suiteName) = makeDefaults()
        defer { clearDefaults(named: suiteName) }

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: NotificationCenter(),
            playlistNotificationCenter: NotificationCenter(),
            userDefaults: defaults,
            activePlaylistDefaultsKey: selectionDefaultsKey,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.migrationQueue")
        )

        coordinator.start()
        await waitUntil("fallback active playlist") {
            coordinator.activePlaylistID == earlyPlaylist.id
        }

        XCTAssertEqual(defaults.string(forKey: selectionDefaultsKey), earlyPlaylist.id.uuidString)
        coordinator.pause()
    }

    func testSetActivePlaylistPersistsSelectionAndControlsAdvance() async throws {
        let earlyDate = Date(timeIntervalSince1970: 100)
        let lateDate = Date(timeIntervalSince1970: 200)
        let earlyPlaylist = makePlaylist(name: "Early", createdAt: earlyDate)
        let latePlaylist = makePlaylist(name: "Late", createdAt: lateDate)
        let playlistStore = MockPlaylistStore(playlists: [earlyPlaylist, latePlaylist])
        let wallpaperService = MockWallpaperService()
        let (defaults, suiteName) = makeDefaults()
        defer { clearDefaults(named: suiteName) }

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: NotificationCenter(),
            playlistNotificationCenter: NotificationCenter(),
            userDefaults: defaults,
            activePlaylistDefaultsKey: selectionDefaultsKey,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.selectQueue")
        )

        coordinator.start()
        await waitUntil("initial active playlist") {
            coordinator.activePlaylistID == earlyPlaylist.id
        }

        coordinator.setActivePlaylist(id: latePlaylist.id)
        await waitUntil("selected active playlist") {
            coordinator.activePlaylistID == latePlaylist.id
        }

        coordinator.advance()
        await waitUntil("advance after explicit selection") {
            wallpaperService.currentAppliedPlaylists.count == 1
        }

        XCTAssertEqual(wallpaperService.currentAppliedPlaylists.last, latePlaylist.id)
        XCTAssertEqual(defaults.string(forKey: selectionDefaultsKey), latePlaylist.id.uuidString)
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

    func testCoordinatorPostsStateNotifications() async throws {
        let playlist = makePlaylist(name: "Only", createdAt: Date(timeIntervalSince1970: 100))
        let playlistStore = MockPlaylistStore(playlists: [playlist])
        let wallpaperService = MockWallpaperService()
        let stateCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let playlistCenter = NotificationCenter()
        let lock = NSLock()
        var payloads: [[AnyHashable: Any]] = []

        let observer = stateCenter.addObserver(
            forName: .schedulerCoordinatorStateDidChange,
            object: nil,
            queue: nil
        ) { notification in
            lock.withLock {
                payloads.append(notification.userInfo ?? [:])
            }
        }
        defer { stateCenter.removeObserver(observer) }

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: workspaceCenter,
            playlistNotificationCenter: playlistCenter,
            notificationCenter: stateCenter,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.stateQueue")
        )

        coordinator.start()
        await waitUntil("scheduler state start notification") {
            lock.withLock { payloads.contains(where: { ($0[SchedulerNotificationKey.isRunning] as? Bool) == true }) }
        }
        await waitUntil("scheduler active playlist notification") {
            lock.withLock {
                payloads.contains(where: { ($0[SchedulerNotificationKey.activePlaylistID] as? UUID) == playlist.id })
            }
        }

        coordinator.pause()
        await waitUntil("scheduler state pause notification") {
            lock.withLock { payloads.contains(where: { ($0[SchedulerNotificationKey.isRunning] as? Bool) == false }) }
        }
    }

    func testAdvancePostsRotationNotification() async throws {
        let playlist = makePlaylist(name: "Only", createdAt: Date(timeIntervalSince1970: 100))
        let playlistStore = MockPlaylistStore(playlists: [playlist])
        let wallpaperService = MockWallpaperService()
        let stateCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let playlistCenter = NotificationCenter()
        let lock = NSLock()
        var rotatedPlaylistIDs: [UUID] = []

        let observer = stateCenter.addObserver(
            forName: .schedulerCoordinatorDidRotateWallpaper,
            object: nil,
            queue: nil
        ) { notification in
            if let playlistID = notification.userInfo?[SchedulerNotificationKey.playlistID] as? UUID {
                lock.withLock {
                    rotatedPlaylistIDs.append(playlistID)
                }
            }
        }
        defer { stateCenter.removeObserver(observer) }

        let coordinator = DefaultSchedulerCoordinator(
            playlistStore: playlistStore,
            wallpaperService: wallpaperService,
            workspaceNotificationCenter: workspaceCenter,
            playlistNotificationCenter: playlistCenter,
            notificationCenter: stateCenter,
            queue: DispatchQueue(label: "DefaultSchedulerCoordinatorTests.rotationQueue")
        )

        coordinator.start()
        await waitUntil("active playlist before advance") {
            coordinator.activePlaylistID == playlist.id
        }

        coordinator.advance()

        await waitUntil("rotation notification after advance") {
            lock.withLock { rotatedPlaylistIDs.contains(playlist.id) }
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

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "DefaultSchedulerCoordinatorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func clearDefaults(named suiteName: String) {
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }
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

    var currentAppliedPlaylists: [UUID] {
        lock.withLock { appliedPlaylists }
    }

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

    func availableDisplays() -> [DisplayDescriptor] {
        []
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
