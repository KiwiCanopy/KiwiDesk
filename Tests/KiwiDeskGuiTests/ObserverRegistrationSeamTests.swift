import Foundation
import Testing

/// #837: the install and the repair both take the one bounded
/// `register`, so neither can loop over every notification on an
/// app that stalls. `ObserverRegistrationBoundTests` pins the
/// bound; this pins that both sites reach it, and that the only
/// other add is the per-window one.
@Suite("Observer registration wiring (#837)")
struct ObserverRegistrationSeamTests {
    @Test("install and repair register through the one bounded loop")
    func bothSitesTakeTheBound() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/AX/AXApplicationObserver.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let count = { (needle: String) in
            source.components(separatedBy: needle).count - 1
        }
        #expect(
            count("failedAppNotifications = register(Self.appNotifications)")
                == 1
        )
        #expect(
            count(
                "failedAppNotifications = register(\n"
                    + "            Self.appNotifications.filter("
            ) == 1
        )
        // The bounded loop's add and the per-window one.
        #expect(count("AXObserverAddNotification(") == 2)
    }
}
