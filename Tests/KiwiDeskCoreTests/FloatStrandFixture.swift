import AppKit
import CoreGraphics
import Foundation

@testable import KiwiDeskCore

/// The shared fixture of the #1352 suites: a pinned display
/// (#531) and the corner derived from it.
@MainActor
enum FloatStrandFixture {
    static let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )

    static let size = CGSize(width: 800, height: 600)

    static let window = WindowID(1)

    static let original = CGRect(
        x: 300,
        y: 200,
        width: 800,
        height: 600
    )

    static var centred: CGRect {
        FloatRecovery.centred(size, in: bounds)
    }

    static func parked(
        _ corner: TilingEngine.HideCorner = .bottomRight,
        lift: CGFloat = 0
    ) -> CGRect {
        var frame = TilingEngine.stashFrame(
            CGRect(origin: .zero, size: size),
            in: bounds,
            corner: corner
        )
        frame.origin.y -= lift
        return frame
    }

    /// A core whose one shown space is `mode`, pinned to
    /// `bounds` on both display seams (#531), holding one
    /// window at `frame`. Nil where the host has no screen.
    static func makeCore(
        mode: LayoutMode,
        frame: CGRect,
        floating: Bool = false
    ) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in bounds }
        core.tiler.allScreenBounds = { [bounds] }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: window,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: floating
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: window)!
        core.state.workspaces.setMode(space, mode)
        return core
    }
}
