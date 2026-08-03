import Foundation
import CoreGraphics
import AppKit

public class BigDockLockerEngine {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public var lockedDisplayID: CGDirectDisplayID?

    public init() {
        // Default to locking to the primary display
        self.lockedDisplayID = CGMainDisplayID()
    }

    public func start() throws {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.mouseMoved.rawValue)

        let callback: CGEventTapCallBack = { (_, _, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let engine = Unmanaged<BigDockLockerEngine>.fromOpaque(refcon).takeUnretainedValue()

            return engine.handleMouseEvent(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        )

        guard let tap = eventTap else {
            let granted = PermissionManager.isAccessibilityGranted()
            let message = "Failed to create event tap. Accessibility: \(granted ? "TRUSTED" : "NOT TRUSTED")."
            print(message)
            throw NSError(domain: "BigDockLockerEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }

    private func handleMouseEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let location = event.location
        let screens = NSScreen.screens

        // Find which screen the mouse is currently on
        // NSScreen.screens are ordered: [0] is primary.
        // Screen coords: (0,0) is bottom-left of primary.
        // CGEvent coords: (0,0) is top-left of primary.

        for screen in screens {
            let frame = screen.frame

            // Convert NSScreen frame to CG (top-left origin)
            // CG origin.y = PrimaryScreen.Height - Frame.Origin.Y - Frame.Height
            let primaryHeight = screens[0].frame.height
            let cgFrameY = primaryHeight - frame.origin.y - frame.size.height
            let cgFrame = CGRect(x: frame.origin.x, y: cgFrameY, width: frame.size.width, height: frame.size.height)

            // Check if mouse is in this screen
            if cgFrame.contains(location) {
                // If this is NOT the locked screen, check for bottom edge
                let displayID =
                    screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                        as? CGDirectDisplayID ?? 0

                if let lockedID = lockedDisplayID, displayID != lockedID {
                    let bottomEdge = cgFrame.origin.y + cgFrame.size.height

                    // Danger Zone: bottom 2 pixels
                    if location.y >= (bottomEdge - 2) {
                        var newLocation = location
                        newLocation.y = bottomEdge - 3 // Bounce back up
                        event.location = newLocation
                        return Unmanaged.passRetained(event)
                    }
                }
                break
            }
        }

        return Unmanaged.passRetained(event)
    }
}
