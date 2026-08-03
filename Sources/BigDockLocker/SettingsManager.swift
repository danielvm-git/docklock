import Foundation
import CoreGraphics

@MainActor
public class SettingsManager {
    private enum Keys {
        static let lockedDisplayID = "lockedDisplayID"
        static let launchAtLogin = "launchAtLogin"
    }

    public static let shared = SettingsManager()
    private let defaults = UserDefaults.standard

    private init() {}

    public var lockedDisplayID: CGDirectDisplayID? {
        get {
            let value = defaults.integer(forKey: Keys.lockedDisplayID)
            return value == 0 ? nil : CGDirectDisplayID(value)
        }
        set {
            if let newValue = newValue {
                defaults.set(Int(newValue), forKey: Keys.lockedDisplayID)
            } else {
                defaults.removeObject(forKey: Keys.lockedDisplayID)
            }
        }
    }
}
