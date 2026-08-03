import Testing
import Foundation
@testable import BigDockLocker

struct PermissionsTests {
    @Test func testAXIsProcessTrusted() async throws {
        // This won't change the state, but it confirms the API is reachable
        _ = PermissionManager.isAccessibilityGranted()
    }
}
