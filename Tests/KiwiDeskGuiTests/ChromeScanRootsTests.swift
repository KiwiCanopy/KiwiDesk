import Foundation
import Testing

/// `ChromeScanRoots` is the one list of trees the chrome guards
/// scan (#828), so its read is proven once here rather than by a
/// copy in each guard: a root that yields nothing retires every
/// one of them over that tree in silence (#635).
@Suite("Chrome scan roots")
struct ChromeScanRootsTests {
    @Test("every scan root is actually read")
    func everyScanRootIsRead() throws {
        for root in ChromeScanRoots.urls(from: #filePath) {
            #expect(
                !(try SourceScan.swiftSources(under: root))
                    .isEmpty,
                Comment(
                    rawValue: "\(root.lastPathComponent) yielded "
                        + "no Swift files — the chrome guards no "
                        + "longer cover that tree"
                )
            )
        }
        // Derived from what the scan READ, never from the
        // literal list: deleting a root leaves the loop above
        // green, having faithfully checked whatever remains.
        #expect(
            try ChromeScanRoots.sources(from: #filePath).contains {
                $0.path.contains("/Onboarding/")
            }
        )
    }
}
