import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// A window paired at boot into a floating Space, standing at the
/// column the boot's first pass gave it (#2130). Its record is
/// delivered; a CORNER record — taken while it was parked —
/// carries no original, so it takes the float placement instead
/// of staying at the column, off screen.
@Suite("Cross-session floats with a corner record (#2130)", .serialized)
@MainActor
struct CrossSessionCornerRecordTests: CrossSessionFixture {
    private func screen(_ core: KiwiCore) throws -> CGRect {
        try #require(core.tiler.allScreenBounds().first)
    }

    /// The boot desk: w10 scanned into the shown Space, laid at a
    /// column left of the screen.
    private func core() throws -> (KiwiCore, CGRect) {
        let core = try #require(boot([window(10, "com.a", "A")]))
        let bounds = try screen(core)
        let column = CGRect(
            x: bounds.minX - 500,
            y: bounds.minY + 20,
            width: 600,
            height: 400
        )
        core.state.apply(.windowMoved(WindowID(10), column))
        return (core, column)
    }

    /// The freeze's desk: the record's Space floating and shown.
    private func desk(record: CGRect? = nil) -> StateSnapshot {
        var desk = previous([(F.hidden, "com.a", "A")])
        if let record { desk.windows[0].frame = record }
        desk.spaces = [F.shown, F.hidden].map { id in
            var space = Space(
                id: id,
                windows: id == F.hidden ? [WindowID(500)] : []
            )
            if id == F.hidden { space.mode = .floating }
            return .init(space: space)
        }
        desk.activeSpace = F.hidden.raw
        return desk
    }

    @Test(
        "a record is delivered",
        .enabled(if: NSScreen.main != nil)
    )
    func recordDelivered() throws {
        let (core, _) = try core()
        leave(desk(), in: core)
        arrange(core)
        #expect(space(core, 10) == F.hidden)
        #expect(
            core.tiler.commandedFrame(of: WindowID(10)) == Self.recorded
        )
    }

    @Test(
        "a corner record takes the float placement",
        .enabled(if: NSScreen.main != nil)
    )
    func cornerRecordIsPlaced() throws {
        let (core, column) = try core()
        let bounds = try screen(core)
        let corner = TilingEngine.stashFrame(
            Self.recorded,
            in: bounds,
            corner: .bottomRight
        )
        #expect(core.tiler.looksStashed(corner))
        leave(desk(record: corner), in: core)
        arrange(core)
        let landed = try #require(
            core.tiler.commandedFrame(of: WindowID(10))
        )
        #expect(landed != column)
        #expect(bounds.contains(landed))
    }
}
