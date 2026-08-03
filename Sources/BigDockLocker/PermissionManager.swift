@preconcurrency import Foundation
@preconcurrency import AppKit

public class PermissionManager {
    public static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    public static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
