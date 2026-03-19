import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var services: ServiceRegistry?
    private var mainWindowController: NSWindowController?
    private var compactWindowController: NSWindowController?
    private let userDefaults = AppEnvironment.userDefaults
    private let mainWindowFrameKey = "MainWindowFrame"
    private let compactWindowFrameKey = "CompactWindowFrame"
    private let mainWindowFrameScaleVersionKey = "MainWindowFrameScaleVersion"
    private let mainWindowFrameScaleVersion = 1
    private let defaultMainWindowSize = NSSize(width: 1160, height: 760)
    private let minimumMainWindowSize = NSSize(width: 920, height: 620)
    private let defaultCompactWindowSize = NSSize(width: 760, height: 500)
    private let minimumCompactWindowSize = NSSize(width: 620, height: 420)

    func configure(with services: ServiceRegistry) {
        self.services = services
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "WPs"
            if #available(macOS 11, *) {
                button.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Open Quick Access")
                button.imagePosition = .imageLeading
                button.image?.isTemplate = true
            }
            button.target = self
            button.action = #selector(toggleCompactWindow(_:))
        }

        self.statusItem = statusItem
        buildMainWindow()
        buildCompactWindow()

        services?.appearanceObserver.startObserving()
        services?.schedulerCoordinator.start()
        showMainWindow()
    }

    private func buildMainWindow() {
        guard let services else { return }
        migrateSavedMainWindowFrameIfNeeded()

        let rootView = MainWindowView()
            .environmentObject(services)
            .environmentObject(services.schedulerState)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WPswitcher"
        window.identifier = NSUserInterfaceItemIdentifier("mainWindow")
        if loadMainWindowFrame() == nil {
            window.setContentSize(defaultMainWindowSize)
        }
        window.setFrameAutosaveName("MainWindow")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        if #available(macOS 11, *) {
            window.toolbarStyle = .unified
        }
        window.minSize = minimumMainWindowSize
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.delegate = self

        let controller = NSWindowController(window: window)
        mainWindowController = controller
    }

    private func buildCompactWindow() {
        guard let services else { return }

        let rootView = WallpaperLibraryView(layoutMode: .compactDesktop)
            .environmentObject(services)
            .environmentObject(services.schedulerState)

        let hostingController = NSHostingController(rootView: rootView)
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = "Quick Access"
        panel.identifier = NSUserInterfaceItemIdentifier("compactWindow")
        if loadWindowFrame(forKey: compactWindowFrameKey) == nil {
            panel.setContentSize(defaultCompactWindowSize)
        }
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.minSize = minimumCompactWindowSize
        panel.delegate = self
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let controller = NSWindowController(window: panel)
        compactWindowController = controller
    }

    private func showMainWindow() {
        guard let window = mainWindowController?.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if let savedFrame = loadMainWindowFrame() {
            DispatchQueue.main.async {
                window.setFrame(savedFrame, display: false)
            }
        }
        window.makeKeyAndOrderFront(nil)
    }

    func showMainWindowFromCommand() {
        showMainWindow()
    }

    func hideMainWindowFromCommand() {
        hideMainWindow()
    }

    func showCompactWindowFromCommand() {
        showCompactWindow(anchorToStatusItem: false)
    }

    func hideCompactWindowFromCommand() {
        hideCompactWindow()
    }

    private func hideMainWindow() {
        if let window = mainWindowController?.window {
            saveWindowFrame(window.frame, forKey: mainWindowFrameKey)
            window.orderOut(nil)
        }
    }

    private func showCompactWindow(anchorToStatusItem: Bool) {
        guard let window = compactWindowController?.window else { return }
        if let savedFrame = loadWindowFrame(forKey: compactWindowFrameKey) {
            window.setFrame(savedFrame, display: false)
        } else if anchorToStatusItem {
            positionCompactWindow(window)
        }
        window.orderFrontRegardless()
        window.makeKey()
    }

    private func hideCompactWindow() {
        if let window = compactWindowController?.window {
            saveWindowFrame(window.frame, forKey: compactWindowFrameKey)
            window.orderOut(nil)
        }
    }

    @objc private func toggleCompactWindow(_ sender: Any?) {
        guard let window = compactWindowController?.window else { return }
        if window.isVisible {
            hideCompactWindow()
        } else {
            showCompactWindow(anchorToStatusItem: true)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        saveFrame(for: sender)
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveFrame(for: window)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let window = mainWindowController?.window {
            saveWindowFrame(window.frame, forKey: mainWindowFrameKey)
        }
        if let window = compactWindowController?.window {
            saveWindowFrame(window.frame, forKey: compactWindowFrameKey)
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveFrame(for: window)
    }


    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveFrame(for: window)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        guard window.identifier?.rawValue == "compactWindow" else { return }
        hideCompactWindow()
    }

    private func loadMainWindowFrame() -> NSRect? {
        loadWindowFrame(forKey: mainWindowFrameKey)
    }

    private func loadWindowFrame(forKey key: String) -> NSRect? {
        guard let frameString = userDefaults.string(forKey: key) else { return nil }
        return NSRectFromString(frameString)
    }

    private func migrateSavedMainWindowFrameIfNeeded() {
        let savedVersion = userDefaults.integer(forKey: mainWindowFrameScaleVersionKey)
        guard savedVersion < mainWindowFrameScaleVersion else { return }
        defer {
            userDefaults.set(mainWindowFrameScaleVersion, forKey: mainWindowFrameScaleVersionKey)
        }

        guard let frameString = userDefaults.string(forKey: mainWindowFrameKey) else { return }
        var frame = NSRectFromString(frameString)
        guard frame.width > 0, frame.height > 0 else { return }

        let shouldScale = frame.width < minimumMainWindowSize.width || frame.height < minimumMainWindowSize.height
        guard shouldScale else { return }

        let scaledSize = NSSize(
            width: max(minimumMainWindowSize.width, frame.width),
            height: max(minimumMainWindowSize.height, frame.height)
        )

        let widthDelta = frame.width - scaledSize.width
        let heightDelta = frame.height - scaledSize.height
        frame.origin.x += widthDelta / 2
        frame.origin.y += heightDelta / 2
        frame.size = scaledSize

        userDefaults.set(NSStringFromRect(frame), forKey: mainWindowFrameKey)
    }

    private func saveFrame(for window: NSWindow) {
        switch window.identifier?.rawValue {
        case "compactWindow":
            saveWindowFrame(window.frame, forKey: compactWindowFrameKey)
        case "mainWindow":
            saveWindowFrame(window.frame, forKey: mainWindowFrameKey)
        default:
            break
        }
    }

    private func saveWindowFrame(_ frame: NSRect, forKey key: String) {
        userDefaults.set(NSStringFromRect(frame), forKey: key)
    }

    private func positionCompactWindow(_ window: NSWindow) {
        guard
            let button = statusItem?.button,
            let buttonWindow = button.window
        else {
            window.center()
            return
        }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        let visibleFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let originX = min(
            max(visibleFrame.minX + 12, screenFrame.midX - (window.frame.width / 2)),
            visibleFrame.maxX - window.frame.width - 12
        )
        let originY = max(visibleFrame.minY + 12, screenFrame.minY - window.frame.height - 8)
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
