import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// SkyLight's per-window level is the public list's layer (#2531):
/// the list read swapped one for the other, and a window detection
/// judges on the wrong layer floats or tiles wrongly. Reads the
/// host's windows, read-only; a window whose layer moved or that
/// closed between two snapshots is not judged, since other suites
/// order their panels in and out meanwhile.
@Suite("Window level read (#2531)")
struct WindowLevelReadTests {
    private func snapshot() -> [UInt32: (pid_t, Int)] {
        let list =
            CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var out: [UInt32: (pid_t, Int)] = [:]
        for info in list {
            guard let number = info[kCGWindowNumber as String] as? Int,
                let raw = UInt32(exactly: number),
                let pid = info[kCGWindowOwnerPID as String] as? pid_t
            else { continue }
            out[raw] = (pid, info[kCGWindowLayer as String] as? Int ?? 0)
        }
        return out
    }

    @Test(
        "every listed window's level is its public layer",
        .enabled(if: SkyLight.readsWindowLevel)
    )
    func levelIsThePublicLayer() {
        let before = snapshot()
        var levels: [UInt32: Int?] = [:]
        for raw in before.keys.sorted().prefix(200) {
            levels[raw] = SkyLight.windowLevel(raw)
        }
        let after = snapshot()
        var compared = 0
        for (raw, level) in levels {
            guard let was = before[raw], let now = after[raw],
                was.1 == now.1
            else { continue }
            #expect(level == was.1, "window \(raw)")
            compared += 1
        }
        #expect(compared > 0)
    }

    @Test("a window the server does not know reads no layer")
    func unknownWindowReadsNone() {
        let unknown = WindowID(UInt32.max - 7)
        #expect(FloatDetection.layerReader(pid: 0)(unknown) == nil)
        #expect(FloatDetection.windowLayer(of: unknown) == nil)
    }
}
