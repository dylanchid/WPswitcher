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

    func testCreateAndFetchPlaylist() async throws {
        let light = try await store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/one.jpg"), displayName: "One", bookmarkData: nil))
        let dark = try await store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/two.jpg"), displayName: "Two", bookmarkData: nil))

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

        let created = try await store.createPlaylist(draft)
        let fetched = try await store.fetchPlaylists()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, created.id)
        XCTAssertEqual(fetched.first?.entries.count, 1)
        XCTAssertEqual(fetched.first?.entries.first?.lightWallpaper?.id, light.id)
        XCTAssertEqual(fetched.first?.entries.first?.darkWallpaper?.id, dark.id)
    }

    func testUpdatePlaylistAppliesChanges() async throws {
        let wallOne = try await store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/one.jpg"), displayName: "One", bookmarkData: nil))
        let wallTwo = try await store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/two.jpg"), displayName: "Two", bookmarkData: nil))
        let wallThree = try await store.upsertWallpaper(WallpaperDraft(url: URL(fileURLWithPath: "/tmp/three.jpg"), displayName: "Three", bookmarkData: nil))

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

        let created = try await store.createPlaylist(initial)
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

        let updated = try await store.updatePlaylist(updatedDraft)

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

    func testFetchPlaylistByIdentifier() async throws {
        let draft = PlaylistDraft(
            id: nil,
            name: "Sample",
            intervalMinutes: 20,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        let created = try await store.createPlaylist(draft)
        let fetched = try await store.fetchPlaylist(id: created.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.name, "Sample")
    }

    func testUpdatePlaylistWithoutIdentifierThrows() async throws {
        let draft = PlaylistDraft(
            id: nil,
            name: "Nameless",
            intervalMinutes: 10,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        do {
            _ = try await store.updatePlaylist(draft)
            XCTFail("Should have thrown invalidDraft error")
        } catch PlaylistStoreError.invalidDraft {
            // Success
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreatePlaylistWithMissingWallpaperReferenceThrows() async throws {
        let missingWallpaperID = UUID()
        let draft = PlaylistDraft(
            id: nil,
            name: "Broken Playlist",
            intervalMinutes: 15,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [
                PlaylistEntryDraft(id: UUID(), order: 0, lightWallpaperId: missingWallpaperID, darkWallpaperId: nil)
            ],
            displayAssignments: []
        )

        do {
            _ = try await store.createPlaylist(draft)
            XCTFail("Expected missing wallpaper references error")
        } catch PlaylistStoreError.missingWallpaperReferences(let missingIds) {
            XCTAssertEqual(missingIds, [missingWallpaperID])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeletePlaylistRemovesEntity() async throws {
        let draft = PlaylistDraft(
            id: nil,
            name: "Temp",
            intervalMinutes: 45,
            playbackMode: .sequential,
            multiDisplayPolicy: .mirror,
            entries: [],
            displayAssignments: []
        )

        let playlist = try await store.createPlaylist(draft)
        try await store.deletePlaylist(id: playlist.id)

        let playlists = try await store.fetchPlaylists()
        XCTAssertTrue(playlists.isEmpty)
    }

    func testUpsertWallpaperCreatesAndUpdatesRecord() async throws {
        let url = URL(fileURLWithPath: "/tmp/shared.jpg")
        let draft = WallpaperDraft(url: url, displayName: "Original", bookmarkData: nil)
        let created = try await store.upsertWallpaper(draft)

        XCTAssertEqual(created.url, url)
        XCTAssertEqual(created.displayName, "Original")

        let updated = try await store.upsertWallpaper(WallpaperDraft(url: url, displayName: "Updated", bookmarkData: nil))
        XCTAssertEqual(created.id, updated.id)
        XCTAssertEqual(updated.displayName, "Updated")
    }
}
