import Foundation
import AppKit

public struct DisplayInfo: Identifiable, Equatable {
    public let id: CGDirectDisplayID
    public let name: String
    public let isMain: Bool

    public var identifier: String { "\(id)" }
}

public class DisplayManager {
    public init() {}

    public func getAllDisplays() throws -> [DisplayInfo] {
        return NSScreen.screens.map { screen in
            let description = screen.deviceDescription
            let displayID = description[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0

            // On modern macOS, getting the localized name might require more work, 
            // but for now we'll use a placeholder or the screen object.
            let name = screen.localizedName
            let isMain = screen == NSScreen.main

            return DisplayInfo(id: displayID, name: name, isMain: isMain)
        }
    }
}
