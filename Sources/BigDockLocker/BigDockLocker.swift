import SwiftUI
import AppKit

@main
struct BigDockLockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon if we want it to be a pure menu bar app
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
    }
}

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var dashboardWindow: NSWindow?
    private let viewModel = BigDockLockerViewModel()

    override init() {
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "lock.display", accessibilityDescription: "Big DockLocker")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Dashboard", action: #selector(showDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        // Ensure menu targets this controller
        menu.items.forEach { $0.target = self }

        statusItem?.menu = menu
    }

    @objc func showDashboard() {
        if dashboardWindow == nil {
            let contentView = DashboardView(viewModel: viewModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("Dashboard")
            window.contentView = NSHostingView(rootView: contentView)
            window.isReleasedWhenClosed = false
            window.title = "Big DockLocker Dashboard"
            dashboardWindow = window
        }

        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
