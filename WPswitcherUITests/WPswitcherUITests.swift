import XCTest

final class WPswitcherUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--reset-defaults"]
        app.launchEnvironment["WPS_DEFAULTS_SUITE"] = "WPswitcherUITests.\(name)"
        app.launch()
    }

    func testMainWindowCanHideAndReopenFromCommands() {
        let mainWindow = app.windows["WPswitcher"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))

        clickAppMenuItem(named: "Hide Main Window")
        XCTAssertTrue(waitForWindowToDisappear(mainWindow, timeout: 5))

        clickAppMenuItem(named: "Show Main Window")
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
    }

    private func waitForWindowToDisappear(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func clickAppMenuItem(named title: String) {
        let appMenu = app.menuBars.menuBarItems["WPswitcher"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 5))
        appMenu.click()

        let menuItem = app.menuItems[title]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.click()
    }
}
