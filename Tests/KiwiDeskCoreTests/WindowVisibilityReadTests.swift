import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// SkyLight's per-window on-screen read is the public list's
/// `kCGWindowIsOnscreen` (#2634): the raise gate swapped one for the
/// other, and a wrong answer either switches Desktops on a raise or
/// refuses a focus. Reads the host's windows, read-only; a window
/// whose flag moved between two snapshots is not judged, since other
/// suites order their panels in and out meanwhile.
@Suite("Window on-screen read (#2634)")
struct WindowVisibilityReadTests {
    private func snapshot() -> [UInt32: Bool] {
        let list =
            CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var out: [UInt32: Bool] = [:]
        for info in list {
            guard let number = info[kCGWindowNumber as String] as? Int,
                let raw = UInt32(exactly: number)
            else { continue }
            out[raw] =
                info[kCGWindowIsOnscreen as String] as? Bool
                ?? false
        }
        return out
    }

    @Test(
        "every window SkyLight answers reads the public flag",
        .enabled(if: SkyLight.windowIsVisibleSymbol.function != nil)
    )
    func readIsThePublicFlag() {
        let before = snapshot()
        var reads: [UInt32: Bool?] = [:]
        for raw in before.keys.sorted().prefix(300) {
            reads[raw] = SkyLight.windowOnScreen(raw)
        }
        let after = snapshot()
        var compared = 0
        for (raw, read) in reads {
            guard let read, let was = before[raw],
                after[raw] == was
            else { continue }
            #expect(read == was, "window \(raw)")
            compared += 1
        }
        #expect(compared > 0)
    }

    @Test("a window the server does not know reads nothing")
    func unknownWindowReadsNone() {
        let unknown = UInt32.max - 7
        #expect(SkyLight.windowOnScreen(unknown) == nil)
        #expect(FloatDetection.isOnScreen(WindowID(unknown)) == nil)
    }
}
