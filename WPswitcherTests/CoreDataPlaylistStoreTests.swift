import XCTest
@testable import WPswitcher

final class CoreDataPlaylistStoreTests: XCTestCase {
    private var persistence: PersistenceController!
    private var store: CoreDataPlaylistStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = PersistenceController(inMemory: true)
        store = CoreDataPlaylistStore(persistence: persistence)
    }

    override func tearDownWithError() throws {
        store = nil
        persistence = nil
        try super.tearDownWithError()
    }

    func testCreateAndFetchPlaylist() throws {
        let light = try store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/one.jpg"), displayName: "One", bookmarkData: nil))
        let dark = try store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/two.jpg"), displayName: "Two", bookmarkData: nil))

        let draft = PlaylistDraft(
            id: nil,
            name: "Morning",
            intervalMinutes: 30,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [
                PlaylistEntryDraft(id: UUID(), order: 0, lightWallpaperId: light.id, darkWallpaperId: dark.id)
            ],
            displayAssignments: []
        )

        let created = try store.createPlaylist(draft)
        let fetched = try store.fetchPlaylists()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, created.id)
        XCTAssertEqual(fetched.first?.entries.count, 1)
        XCTAssertEqual(fetched.first?.entries.first?.lightWallpaper?.id, light.id)
        XCTAssertEqual(fetched.first?.entries.first?.darkWallpaper?.id, dark.id)
    }

    func testUpdatePlaylistAppliesChanges() throws {
        let wallOne = try store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/one.jpg"), displayName: "One", bookmarkData: nil))
        let wallTwo = try store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/two.jpg"), displayName: "Two", bookmarkData: nil))
        let wallThree = try store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/three.jpg"), displayName: "Three", bookmarkData: nil))

        let initial = PlaylistDraft(
            id: nil,
            name: "Morning",
            intervalMinutes: 30,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [
                PlaylistEntryDraft(id: UUID(), order: 0, lightWallpaperId: wallOne.id, darkWallpaperId: nil)
            ],
            displayAssignments: []
        )

        let created = try store.createPlaylist(initial)
        let updatedDraft = PlaylistDraft(
            id: created.id,
            name: "Evening",
            intervalMinutes: 45,
            playbackMode: .random,
            multiDisplayPolicy: .perDisplay,
            entries: [
                PlaylistEntryDraft(id: UUID(), order: 0, lightWallpaperId: wallTwo.id, darkWallpaperId: wallThree.id),
                PlaylistEntryDraft(id: UUID(), order: 1, lightWallpaperId: wallOne.id, darkWallpaperId: nil)
            ],
            displayAssignments: [
                DisplayAssignmentDraft(id: UUID(), displayID: "DISPLAY-1", order: 0, lightWallpaperId: wallTwo.id, darkWallpaperId: wallThree.id)
            ]
        )

        let updated = try store.updatePlaylist(updatedDraft)

        XCTAssertEqual(updated.name, "Evening")
        XCTAssertEqual(updated.intervalMinutes, 45)
        XCTAssertEqual(updated.playbackMode, .random)
        XCTAssertEqual(updated.multiDisplayPolicy, .perDisplay)
        XCTAssertEqual(updated.entries.count, 2)
        XCTAssertEqual(updated.entries.first?.lightWallpaper?.id, wallTwo.id)
        XCTAssertEqual(updated.entries.first?.darkWallpaper?.id, wallThree.id)
        XCTAssertEqual(updated.displayAssignments.count, 1)
        XCTAssertEqual(updated.displayAssignments.first?.displayID, "DISPLAY-1")
    }

    func testFetchPlaylistByIdentifier() throws {
        let draft = PlaylistDraft(
            id: nil,
            name: "Sample",
            intervalMinutes: 20,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        let created = try store.createPlaylist(draft)
        let fetched = try store.fetchPlaylist(id: created.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.name, "Sample")
    }

    func testUpdatePlaylistWithoutIdentifierThrows() throws {
        let draft = PlaylistDraft(
            id: nil,
            name: "Nameless",
            intervalMinutes: 10,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        XCTAssertThrowsError(try store.updatePlaylist(draft)) { error in
            guard case PlaylistStoreError.invalidDraft = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }

    func testDeletePlaylistRemovesEntity() throws {
        let draft = PlaylistDraft(
            id: nil,
            name: "Temp",
            intervalMinutes: 45,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        let playlist = try store.createPlaylist(draft)
        try store.deletePlaylist(id: playlist.id)

        let playlists = try store.fetchPlaylists()
        XCTAssertTrue(playlists.isEmpty)
    }

    func testUpsertWallpaperCreatesAndUpdatesRecord() throws {
        let url = URL(fileURLWithPath: "/tmp/shared.jpg")
        let draft = WallpaperDraft(url: url, displayName: "Original", bookmarkData: nil)
        let created = try store.upsertWallpaper(draft)

        XCTAssertEqual(created.url, url)
        XCTAssertEqual(created.displayName, "Original")

        let updated = try store.upsertWallpaper(WallpaperDraft(url: url, displayName: "Updated", bookmarkData: nil))
        XCTAssertEqual(created.id, updated.id)
        XCTAssertEqual(updated.displayName, "Updated")
    }
}
