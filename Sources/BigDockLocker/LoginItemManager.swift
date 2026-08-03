import Foundation
import ServiceManagement

@MainActor
public class LoginItemManager {
    public static let shared = LoginItemManager()

    private let service = SMAppService.mainApp

    public var isEnabled: Bool {
        return service.status == .enabled
    }

    public func toggle() {
        do {
            if isEnabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
    }
}
