import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import BigDockLocker

struct BigDockLockerEngineTests {

    @Test func testCoordinateConversion() async throws {
        // Mocking screen setup
        // Primary screen: (0, 0, 1920, 1080)
        // Secondary screen: (1920, 0, 1920, 1080)

        // In CG coords (top-left 0,0):
        // Primary: x:0, y:0, w:1920, h:1080
        // Secondary: x:1920, y:0, w:1920, h:1080

        let primaryHeight: CGFloat = 1080

        // Let's test the logic inside handleMouseEvent (mathematically)
        func getCGFrame(nsscreenFrame frame: CGRect, primaryHeight: CGFloat) -> CGRect {
            let cgFrameY = primaryHeight - frame.origin.y - frame.size.height
            return CGRect(x: frame.origin.x, y: cgFrameY, width: frame.size.width, height: frame.size.height)
        }

        // Test primary screen conversion (origin 0,0 in NSScreen)
        let primaryNSFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let primaryCGFrame = getCGFrame(nsscreenFrame: primaryNSFrame, primaryHeight: primaryHeight)
        #expect(primaryCGFrame.origin.y == 0)
        #expect(primaryCGFrame.size.height == 1080)

        // Test secondary screen conversion (placed to the right, same height)
        let secondaryNSFrame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let secondaryCGFrame = getCGFrame(nsscreenFrame: secondaryNSFrame, primaryHeight: primaryHeight)
        #expect(secondaryCGFrame.origin.y == 0)
        #expect(secondaryCGFrame.origin.x == 1920)

        // Test bottom edge calculation
        let bottomEdge = secondaryCGFrame.origin.y + secondaryCGFrame.size.height
        #expect(bottomEdge == 1080)

        // Check "Danger Zone" logic
        let mouseAtBottom = CGPoint(x: 2000, y: 1079) // 1 pixel from bottom of secondary
        let isAtBottom = mouseAtBottom.y >= (bottomEdge - 2)
        #expect(isAtBottom == true)
    }
}
