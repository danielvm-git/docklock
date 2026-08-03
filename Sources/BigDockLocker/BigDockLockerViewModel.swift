import Foundation
import Combine
import CoreGraphics

@MainActor
public class BigDockLockerViewModel: ObservableObject {
    @Published public var displays: [DisplayInfo] = []
    @Published public var lockedDisplayID: CGDirectDisplayID?
    @Published public var isGranted: Bool = false
    @Published public var isRunning: Bool = false

    @Published public var launchAtLogin: Bool = false

    private let displayManager = DisplayManager()
    private let engine = BigDockLockerEngine()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.lockedDisplayID = SettingsManager.shared.lockedDisplayID
        self.launchAtLogin = LoginItemManager.shared.isEnabled
        engine.lockedDisplayID = self.lockedDisplayID
        refresh()

        // Start engine automatically if permissions are granted
        if PermissionManager.isAccessibilityGranted() {
            startEngine()
        }

        // Timer to refresh displays periodically or on demand
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    public func refresh() {
        isGranted = PermissionManager.isAccessibilityGranted()
        do {
            displays = try displayManager.getAllDisplays()
        } catch {
            print("Failed to fetch displays: \(error)")
        }
    }

    public func toggleLock(for displayID: CGDirectDisplayID) {
        if lockedDisplayID == displayID {
            lockedDisplayID = nil
            engine.lockedDisplayID = nil
        } else {
            lockedDisplayID = displayID
            engine.lockedDisplayID = displayID
        }
        SettingsManager.shared.lockedDisplayID = lockedDisplayID
    }

    public func toggleLaunchAtLogin() {
        LoginItemManager.shared.toggle()
        launchAtLogin = LoginItemManager.shared.isEnabled
    }

    public func startEngine() {
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Engine failed to start: \(error)")
        }
    }

    public func stopEngine() {
        engine.stop()
        isRunning = false
    }

    public func requestPermissions() {
        PermissionManager.requestAccessibility()
    }

    public func openSettings() {
        PermissionManager.openAccessibilitySettings()
    }
}
