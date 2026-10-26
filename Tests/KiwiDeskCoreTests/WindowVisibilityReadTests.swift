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

    private static func publicFlag(_ raw: UInt32) -> Bool? {
        let list =
            CGWindowListCopyWindowInfo([.optionIncludingWindow], raw)
            as? [[String: Any]]
        return list?.first.map {
            $0[kCGWindowIsOnscreen as String] as? Bool ?? false
        }
    }

    @Test(
        "every window SkyLight answers reads the public flag",
        .enabled(if: SkyLight.readsWindowOnScreen)
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
            compared += 1
            // A window toggled twice between the snapshots is read
            // again once rather than judged on the stale pair.
            guard read != was else { continue }
            #expect(
                SkyLight.windowOnScreen(raw) == Self.publicFlag(raw),
                "window \(raw)"
            )
        }
        #expect(compared > 0)
    }

    /// The public read has no entry for a window ordered out, and
    /// the gate abstains on that nil; visible reads false there, so
    /// it may answer only for a window ordered in. A host read
    /// cannot red this: `.optionAll` lists such a window off screen.
    @Test("visible answers only for a window ordered in")
    func visibleNeedsOrderedIn() {
        var asked = 0
        func read(_ orderedIn: Bool?, _ visible: Bool?) -> Bool? {
            SkyLight.onScreen(orderedIn: orderedIn) {
                asked += 1
                return visible
            }
        }
        #expect(read(false, false) == nil)
        #expect(read(nil, true) == nil)
        #expect(asked == 0)
        #expect(read(true, nil) == nil)
        #expect(read(true, false) == false)
        #expect(read(true, true) == true)
    }

    @Test("a window the server does not know reads nothing")
    func unknownWindowReadsNone() {
        let unknown = UInt32.max - 7
        // SkyLight answers an unknown id as ordered out, not as an
        // error (measured 2026-10-26), which the composite reads nil.
        #expect(SkyLight.windowOrderedIn(unknown) != true)
        #expect(SkyLight.windowOnScreen(unknown) == nil)
        #expect(FloatDetection.isOnScreen(WindowID(unknown)) == nil)
    }
}
