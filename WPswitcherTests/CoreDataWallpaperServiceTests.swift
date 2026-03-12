import XCTest
@testable import WPswitcher

final class CoreDataWallpaperServiceTests: XCTestCase {
    private var persistence: PersistenceController!
    private var playlistStore: CoreDataPlaylistStore!
    private var service: CoreDataWallpaperService!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = PersistenceController(inMemory: true)
        playlistStore = CoreDataPlaylistStore(persistence: persistence)
        service = CoreDataWallpaperService(persistence: persistence, playlistStore: playlistStore)
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory, FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        service = nil
        playlistStore = nil
        persistence = nil
        try super.tearDownWithError()
    }

    func testImportSingleWallpaperCreatesBookmark() async throws {
        let fileURL = try makeTestImage(named: "sample")
        let records = try await service.importWallpapers(from: [fileURL])
        XCTAssertEqual(records.count, 1)
        XCTAssertNotNil(records.first?.bookmarkData)

        let fetched = try await service.fetchLibrary()
        XCTAssertEqual(fetched.first?.id, records.first?.id)
    }

    func testResolveAccessDetectsMissingFile() async throws {
        let fileURL = try makeTestImage(named: "toDelete")
        let records = try await service.importWallpapers(from: [fileURL])
        XCTAssertEqual(records.count, 1)
        let record = records[0]

        // Remove file to simulate missing state
        try FileManager.default.removeItem(at: fileURL)

        let resolution = service.resolveAccess(for: record)
        if case .available = resolution {
            XCTFail("Expected missing resolution after deleting file")
        }
    }

    func testAssignmentLookupUsesLatestValueForDuplicateDisplayID() {
        let first = DisplayAssignmentRecord(
            id: UUID(),
            displayID: "DISPLAY-1",
            order: 0,
            lightWallpaper: nil,
            darkWallpaper: nil
        )
        let duplicate = DisplayAssignmentRecord(
            id: UUID(),
            displayID: "DISPLAY-1",
            order: 1,
            lightWallpaper: nil,
            darkWallpaper: nil
        )
        let emptyID = DisplayAssignmentRecord(
            id: UUID(),
            displayID: "   ",
            order: 2,
            lightWallpaper: nil,
            darkWallpaper: nil
        )

        let lookup = service.assignmentLookup(for: [first, duplicate, emptyID])
        XCTAssertEqual(lookup.count, 1)
        XCTAssertEqual(lookup["DISPLAY-1"]?.id, duplicate.id)
    }

    func testAvailableDisplaysReturnsInjectedDescriptors() {
        let expected = [
            DisplayDescriptor(id: "200", name: "Projector"),
            DisplayDescriptor(id: "100", name: "Studio Display")
        ]
        let service = CoreDataWallpaperService(
            persistence: persistence,
            playlistStore: playlistStore,
            displayProvider: { expected }
        )

        XCTAssertEqual(service.availableDisplays(), expected)
    }

    func testWallpaperAssignmentsPreferPerDisplayMatchBeforeFallback() {
        let defaultWallpaper = makeWallpaperRecord(name: "default")
        let assignedWallpaper = makeWallpaperRecord(name: "assigned")
        let entry = PlaylistEntryRecord(
            id: UUID(),
            order: 0,
            lightWallpaper: defaultWallpaper,
            darkWallpaper: nil
        )
        let playlist = PlaylistRecord(
            id: UUID(),
            name: "Displays",
            intervalMinutes: 15,
            createdAt: Date(),
            playbackMode: .sequential,
            multiDisplayPolicy: .perDisplay,
            entries: [entry],
            displayAssignments: [
                DisplayAssignmentRecord(
                    id: UUID(),
                    displayID: "DISPLAY-2",
                    order: 0,
                    lightWallpaper: assignedWallpaper,
                    darkWallpaper: nil
                )
            ]
        )

        let routed = service.wallpaperAssignments(
            for: entry,
            playlist: playlist,
            displayIdentifiers: ["DISPLAY-1", "DISPLAY-2", nil],
            preferDark: false
        )

        XCTAssertEqual(routed["DISPLAY-1"]?.id, defaultWallpaper.id)
        XCTAssertEqual(routed["DISPLAY-2"]?.id, assignedWallpaper.id)
        XCTAssertEqual(routed.count, 2)
    }

    func testWallpaperAssignmentsUseDarkVariantForPerDisplayMatch() {
        let lightWallpaper = makeWallpaperRecord(name: "light")
        let darkWallpaper = makeWallpaperRecord(name: "dark")
        let entry = PlaylistEntryRecord(
            id: UUID(),
            order: 0,
            lightWallpaper: lightWallpaper,
            darkWallpaper: nil
        )
        let playlist = PlaylistRecord(
            id: UUID(),
            name: "Displays",
            intervalMinutes: 15,
            createdAt: Date(),
            playbackMode: .sequential,
            multiDisplayPolicy: .perDisplay,
            entries: [entry],
            displayAssignments: [
                DisplayAssignmentRecord(
                    id: UUID(),
                    displayID: "DISPLAY-1",
                    order: 0,
                    lightWallpaper: lightWallpaper,
                    darkWallpaper: darkWallpaper
                )
            ]
        )

        let routed = service.wallpaperAssignments(
            for: entry,
            playlist: playlist,
            displayIdentifiers: ["DISPLAY-1"],
            preferDark: true
        )

        XCTAssertEqual(routed["DISPLAY-1"]?.id, darkWallpaper.id)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeTestImage(named: String) throws -> URL {
        let destination = tempDirectory.appendingPathComponent("\(named).png")
        let pngData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HwAFAAL/9lRtNwAAAABJRU5ErkJggg==")!
        try pngData.write(to: destination)
        return destination
    }

    private func makeWallpaperRecord(name: String) -> WallpaperRecord {
        WallpaperRecord(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/\(name).jpg"),
            displayName: "\(name).jpg",
            createdAt: Date(),
            bookmarkData: nil
        )
    }
}
