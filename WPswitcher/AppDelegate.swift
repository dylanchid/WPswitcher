import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var services: ServiceRegistry?
    private var mainWindowController: NSWindowController?

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
        window.setContentSize(NSSize(width: 980, height: 640))
        window.setFrameAutosaveName("MainWindow")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        mainWindowController = controller
    }

    private func showMainWindow() {
        guard let window = mainWindowController?.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func hideMainWindow() {
        mainWindowController?.window?.orderOut(nil)
    }

    @objc private func toggleMainWindow(_ sender: Any?) {
        guard let window = mainWindowController?.window else { return }
        if window.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }
}
