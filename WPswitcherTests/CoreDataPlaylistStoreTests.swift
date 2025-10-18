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
        let draft = PlaylistDraft(
            name: "Morning",
            intervalMinutes: 30,
            wallpapers: [
                WallpaperDraft(url: URL(fileURLWithPath: "/tmp/one.jpg"), displayName: "One", bookmarkData: nil),
                WallpaperDraft(url: URL(fileURLWithPath: "/tmp/two.jpg"), displayName: "Two", bookmarkData: nil)
            ]
        )

        let created = try store.createPlaylist(draft)
        let fetched = try store.fetchPlaylists()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, created.id)
        XCTAssertEqual(fetched.first?.wallpapers.count, draft.wallpapers.count)
    }

    func testDeletePlaylistRemovesEntity() throws {
        let draft = PlaylistDraft(
            name: "Temp",
            intervalMinutes: 45,
            wallpapers: []
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
