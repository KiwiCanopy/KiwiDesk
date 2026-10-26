import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// SkyLight's per-window level is the public list's layer (#2531):
/// the off-main list read swapped one for the other, and a window
/// detection judges on the wrong layer floats or tiles wrongly.
/// Reads the host's windows, read-only.
@Suite("Window level read (#2531)")
struct WindowLevelReadTests {
    @Test(
        "every listed window's level is its public layer",
        .enabled(if: SkyLight.readsWindowLevel)
    )
    func levelIsThePublicLayer() throws {
        let list = try #require(
            CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                as? [[String: Any]]
        )
        var compared = 0
        for info in list.prefix(200) {
            guard let number = info[kCGWindowNumber as String] as? Int,
                let raw = UInt32(exactly: number),
                let pid = info[kCGWindowOwnerPID as String] as? pid_t
            else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let read = FloatDetection.layerReader(pid: pid)
            #expect(read(WindowID(raw)) == layer, "window \(raw)")
            compared += 1
        }
        #expect(compared > 0)
    }

    @Test("a window the server does not know reads no layer")
    func unknownWindowReadsNone() {
        let read = FloatDetection.layerReader(pid: 0)
        #expect(read(WindowID(UInt32.max - 7)) == nil)
    }
}
