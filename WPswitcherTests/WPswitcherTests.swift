import XCTest
@testable import WPswitcher

@MainActor
final class WPswitcherTests: XCTestCase {
    func testExample() {
        // Placeholder test to ensure target links correctly.
        XCTAssertTrue(true)
    }

    func testRefreshLibraryLoadsAvailableDisplays() async throws {
        let displays = [
            DisplayDescriptor(id: "100", name: "Studio Display"),
            DisplayDescriptor(id: "200", name: "Projector")
        ]
        let wallpaperService = MockEditorWallpaperService(displays: displays)
        let viewModel = PlaylistEditorViewModel(
            playlist: nil,
            playlistStore: MockEditorPlaylistStore(),
            wallpaperService: wallpaperService,
            onSave: { _ in }
        )

        viewModel.refreshLibrary()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.availableDisplays, displays)
    }

    func testSaveChangesRejectsStaleDisplayAssignments() async throws {
        let wallpaperService = MockEditorWallpaperService(displays: [
            DisplayDescriptor(id: "100", name: "Studio Display")
        ])
        let viewModel = PlaylistEditorViewModel(
            playlist: nil,
            playlistStore: MockEditorPlaylistStore(),
            wallpaperService: wallpaperService,
            onSave: { _ in }
        )

        viewModel.refreshLibrary()
        try await Task.sleep(nanoseconds: 50_000_000)
        viewModel.multiDisplayPolicy = .perDisplay
        viewModel.displayAssignments = [
            .init(id: UUID(), displayID: "missing", lightWallpaperId: nil, darkWallpaperId: nil)
        ]

        viewModel.saveChanges()

        XCTAssertEqual(viewModel.errorMessage, "Display assignment 'missing' no longer matches a connected display.")
    }

    func testSchedulerViewStateTracksCoordinatorNotifications() {
        let notificationCenter = NotificationCenter()
        let scheduler = MockSchedulerCoordinator()
        let state = SchedulerViewState(
            schedulerCoordinator: scheduler,
            notificationCenter: notificationCenter
        )
        let playlistID = UUID()

        scheduler.isRunningValue = true
        scheduler.activePlaylistIDValue = playlistID
        notificationCenter.post(
            name: .schedulerCoordinatorStateDidChange,
            object: nil,
            userInfo: [
                SchedulerNotificationKey.isRunning: true,
                SchedulerNotificationKey.activePlaylistID: playlistID
            ]
        )

        XCTAssertTrue(state.isRunning)
        XCTAssertEqual(state.activePlaylistID, playlistID)

        notificationCenter.post(
            name: .schedulerCoordinatorDidRotateWallpaper,
            object: nil,
            userInfo: [SchedulerNotificationKey.playlistID: playlistID]
        )

        XCTAssertEqual(state.lastRotatedPlaylistID, playlistID)
        XCTAssertEqual(state.rotationEventCount, 1)
    }

    func testSchedulerViewStateRefreshesFromCoordinatorSnapshot() {
        let scheduler = MockSchedulerCoordinator()
        let state = SchedulerViewState(
            schedulerCoordinator: scheduler,
            notificationCenter: NotificationCenter()
        )
        let playlistID = UUID()

        scheduler.isRunningValue = true
        scheduler.activePlaylistIDValue = playlistID
        state.refresh(from: scheduler)

        XCTAssertTrue(state.isRunning)
        XCTAssertEqual(state.activePlaylistID, playlistID)
    }
}

private final class MockEditorPlaylistStore: PlaylistStore {
    @discardableResult
    func createPlaylist(_ draft: PlaylistDraft) async throws -> PlaylistRecord {
        fatalError("Unexpected createPlaylist call")
    }

    func fetchPlaylists() async throws -> [PlaylistRecord] { [] }
    func fetchPlaylist(id: UUID) async throws -> PlaylistRecord? { nil }

    @discardableResult
    func updatePlaylist(_ draft: PlaylistDraft) async throws -> PlaylistRecord {
        fatalError("Unexpected updatePlaylist call")
    }

    func deletePlaylist(id: UUID) async throws {}

    @discardableResult
    func upsertWallpaper(_ draft: WallpaperDraft) async throws -> WallpaperRecord {
        fatalError("Unexpected upsertWallpaper call")
    }
}

private final class MockEditorWallpaperService: WallpaperService {
    let displays: [DisplayDescriptor]

    init(displays: [DisplayDescriptor]) {
        self.displays = displays
    }

    @discardableResult
    func apply(entry: PlaylistEntryRecord, from playlist: PlaylistRecord) -> Bool { false }

    func fetchLibrary() async throws -> [WallpaperRecord] { [] }

    @discardableResult
    func importWallpapers(from urls: [URL]) async throws -> [WallpaperRecord] { [] }

    func deleteWallpaper(id: UUID) async throws {}

    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution { .missing }

    func availableDisplays() -> [DisplayDescriptor] { displays }
}

private final class MockSchedulerCoordinator: SchedulerCoordinator {
    var isRunningValue = false
    var activePlaylistIDValue: UUID?

    var isRunning: Bool { isRunningValue }
    var activePlaylistID: UUID? { activePlaylistIDValue }

    func setActivePlaylist(id: UUID) {
        activePlaylistIDValue = id
    }

    func start() {
        isRunningValue = true
    }

    func pause() {
        isRunningValue = false
    }

    func toggleRotation() {
        isRunningValue.toggle()
    }

    func advance() {}
}
