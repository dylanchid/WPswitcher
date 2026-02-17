import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var services: ServiceRegistry?
    private var mainWindowController: NSWindowController?
    private let mainWindowFrameKey = "MainWindowFrame"

    func configure(with services: ServiceRegistry) {
        self.services = services
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "WPs"
            if #available(macOS 11, *) {
                button.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "WPswitcher")
                button.imagePosition = .imageLeading
                button.image?.isTemplate = true
            }
            button.target = self
            button.action = #selector(toggleMainWindow(_:))
        }

        self.statusItem = statusItem
        buildMainWindow()

        services?.appearanceObserver.startObserving()
        services?.schedulerCoordinator.start()
        showMainWindow()
    }

    private func buildMainWindow() {
        guard let services else { return }
        let rootView = MainWindowView()
            .environmentObject(services)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WPswitcher"
        if loadMainWindowFrame() == nil {
            window.setContentSize(NSSize(width: 640, height: 400))
        }
        window.setFrameAutosaveName("MainWindow")
        // Keep compact appearance while allowing toolbar-hosted controls.
        window.styleMask = [.titled, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        if #available(macOS 11, *) {
            window.toolbarStyle = .unifiedCompact
        }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self

        let controller = NSWindowController(window: window)
        mainWindowController = controller
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

    private func hideMainWindow() {
        if let window = mainWindowController?.window {
            saveMainWindowFrame(window.frame)
            window.orderOut(nil)
        }
    }

    @objc private func toggleMainWindow(_ sender: Any?) {
        guard let window = mainWindowController?.window else { return }
        if window.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        saveMainWindowFrame(sender.frame)
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveMainWindowFrame(window.frame)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let window = mainWindowController?.window {
            saveMainWindowFrame(window.frame)
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveMainWindowFrame(window.frame)
    }


    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveMainWindowFrame(window.frame)
    }

    private func loadMainWindowFrame() -> NSRect? {
        let defaults = UserDefaults.standard
        guard let frameString = defaults.string(forKey: mainWindowFrameKey) else { return nil }
        return NSRectFromString(frameString)
    }

    private func saveMainWindowFrame(_ frame: NSRect) {
        let defaults = UserDefaults.standard
        defaults.set(NSStringFromRect(frame), forKey: mainWindowFrameKey)
    }
}
