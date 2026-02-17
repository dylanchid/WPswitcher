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

    // MARK: - Helpers

    @discardableResult
    private func makeTestImage(named: String) throws -> URL {
        let destination = tempDirectory.appendingPathComponent("\(named).png")
        let pngData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HwAFAAL/9lRtNwAAAABJRU5ErkJggg==")!
        try pngData.write(to: destination)
        return destination
    }
}
