import Foundation
import Testing

@testable import KiwiDeskCore

/// The one location verdict every outside launcher reads (#1685):
/// the login item, the service LaunchAgent and the AI page.
@Suite("Running copy location")
struct RunningCopyTests {
    @Test("the bundle path decides the location")
    func location() {
        let app = URL(fileURLWithPath: "/Applications/KiwiDesk.app")
        let translocated = URL(
            fileURLWithPath:
                "/private/var/folders/x/T/AppTranslocation/"
                + "ABC/d/KiwiDesk.app"
        )
        let bare = URL(fileURLWithPath: "/Users/me/.build/release")
        #expect(RunningCopy.location(of: app) == .bundled)
        #expect(RunningCopy.location(of: translocated) == .translocated)
        #expect(RunningCopy.location(of: bare) == .bare)
    }
}
