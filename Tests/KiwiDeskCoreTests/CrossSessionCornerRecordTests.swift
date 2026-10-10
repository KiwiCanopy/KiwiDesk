import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// A window paired at boot into a floating Space, standing at the
/// column the boot's first pass gave it (#2130). Its record is
/// delivered; a CORNER record — taken while it was parked —
/// carries no original, so it takes the one no-original door
/// (`seedWithoutOriginal`) instead of staying at the column, off
/// screen.
@Suite("Cross-session floats with a corner record (#2130)", .serialized)
@MainActor
struct CrossSessionCornerRecordTests: CrossSessionFixture {
    private func screen(_ core: KiwiCore) throws -> CGRect {
        try #require(core.tiler.allScreenBounds().first)
    }

    /// The boot desk: w10 scanned into the shown Space at `at`,
    /// a column left of the screen unless given.
    private func core(at: CGRect? = nil) throws -> (KiwiCore, CGRect) {
        let core = try #require(boot([window(10, "com.a", "A")]))
        let bounds = try screen(core)
        let frame =
            at
            ?? CGRect(
                x: bounds.minX - 500,
                y: bounds.minY + 20,
                width: 600,
                height: 400
            )
        core.state.apply(.windowMoved(WindowID(10), frame))
        return (core, frame)
    }

    /// The freeze's desk: the record's Space shown, floating
    /// unless `tiled`.
    private func desk(
        record: CGRect? = nil,
        tiled: Bool = false
    ) -> StateSnapshot {
        var desk = previous([(F.hidden, "com.a", "A")])
        if let record { desk.windows[0].frame = record }
        desk.spaces = [F.shown, F.hidden].map { id in
            var space = Space(
                id: id,
                windows: id == F.hidden ? [WindowID(500)] : []
            )
            if id == F.hidden, !tiled { space.mode = .floating }
            return .init(space: space)
        }
        desk.activeSpace = F.hidden.raw
        return desk
    }

    private func corner(_ core: KiwiCore) throws -> CGRect {
        let frame = TilingEngine.stashFrame(
            Self.recorded,
            in: try screen(core),
            corner: .bottomRight
        )
        #expect(core.tiler.looksStashed(frame))
        return frame
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
        "a corner record is centred at the window's size",
        .enabled(if: NSScreen.main != nil)
    )
    func cornerRecordIsCentred() throws {
        let (core, column) = try core()
        leave(desk(record: try corner(core)), in: core)
        arrange(core)
        // Centred at the window's own size; the region's height
        // is read before the shelf settles, so the x axis decides.
        let region = try #require(core.floatBounds(on: F.hidden))
        let landed = try #require(
            core.tiler.commandedFrame(of: WindowID(10))
        )
        #expect(landed.size == column.size)
        #expect(abs(landed.midX - region.midX) < 1)
        #expect(try screen(core).contains(landed))
    }

    /// The control: a tiled Space's layout places the window, so a
    /// corner record there is never seeded.
    @Test(
        "a tiled window with a corner record is the layout's",
        .enabled(if: NSScreen.main != nil)
    )
    func tiledWindowIsNotSeeded() throws {
        let (core, _) = try core()
        leave(desk(record: try corner(core), tiled: true), in: core)
        arrange(core)
        #expect(
            core.tiler.commandedFrame(of: WindowID(10))
                == core.tiler.calculatedFrames(state: core.state)[WindowID(10)]
        )
    }
}
