import XCTest
@testable import WPswitcher

final class ErrorManagerTests: XCTestCase {
    @MainActor
    func testQueuedErrorsAutoDismissSequentially() async throws {
        let manager = ErrorManager(autoDismissInterval: 0.05)
        manager.handle(AppError.unknownError("first"), context: "test")
        manager.handle(AppError.unknownError("second"), context: "test")

        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertNil(manager.currentError)
        XCTAssertFalse(manager.showError)
        XCTAssertTrue(manager.errorQueue.isEmpty)
    }
}
