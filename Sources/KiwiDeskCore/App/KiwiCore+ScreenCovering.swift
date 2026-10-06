import AppKit

/// A window covering an entire screen edge for edge — a slide
/// show, a borderless-fullscreen game or player — is PRESENTING
/// there (#1787): the float fit and the gather leave it where its
/// app put it, and the shelf stands down behind it. Judged on the
/// frame alone; the residues that costs are the design entry's.
extension KiwiCore {
    /// How far short of a screen edge a covering frame may stop.
    /// PowerPoint's slide show overscans by 1 pt on every edge.
    nonisolated static let screenCoveringTolerance: CGFloat = 2

    /// Whether `frame` covers `screen` edge for edge, within the
    /// tolerance, both AX coordinates. A window LARGER than its
    /// screen is not presenting — the #1091 fit still owes it.
    nonisolated static func covers(
        _ frame: CGRect,
        _ screen: CGRect
    ) -> Bool {
        let t = screenCoveringTolerance
        return !screen.isEmpty
            && frame.insetBy(dx: -t, dy: -t).contains(screen)
            && screen.insetBy(dx: -t, dy: -t).contains(frame)
    }

    /// A screen's WHOLE frame — menu bar and Dock included — in
    /// AX coordinates.
    static func axFrame(of screen: NSScreen) -> CGRect {
        GeometryUtils.flip(
            screen.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
    }

    /// Whether `frame` (AX coordinates) covers any connected
    /// screen whole, over the `allScreenFrames` seam.
    func coversAScreen(_ frame: CGRect) -> Bool {
        tiler.allScreenFrames().contains { Self.covers(frame, $0) }
    }

    /// Whether the shelf stands down on `display`: a native
    /// fullscreen Space (#670) or a presentation in front. Both
    /// bars ask this one answer.
    func shelfStandsDown(on display: DisplayID) -> Bool {
        !NativeSpaces.currentSpaceIsUser(display: display)
            || showsPresentation(on: display)
    }

    /// The same answer for a GUI surface on `screen` — the
    /// slow-boot notice (#1715).
    public func standsDown(on screen: NSScreen) -> Bool {
        guard let number = screen.screenNumber else { return false }
        return shelfStandsDown(on: DisplayID(number))
    }

    /// Whether the window `display` shows in FRONT covers it.
    /// Front, not focused: PowerPoint's presenter view keeps the
    /// focus on one screen while the show covers the other. A
    /// window is on the screen its MIDPOINT is on — the presenter
    /// view overscans 1 pt into the neighbour screen. The
    /// z-order read is taken only while a tracked window covers
    /// that screen, so a desk without one pays nothing.
    func showsPresentation(on display: DisplayID) -> Bool {
        guard let screen = TilingEngine.screen(for: display)
        else { return false }
        let bounds = Self.axFrame(of: screen)
        guard
            state.windows.all.contains(where: {
                Self.covers($0.frame, bounds)
            }),
            let front = shelves.frontWindowFrames().first(where: {
                bounds.contains(CGPoint(x: $0.midX, y: $0.midY))
            })
        else { return false }
        return Self.covers(front, bounds)
    }

    /// Whether a move or resize took a window into or out of
    /// covering its screen — the bars re-read the stand-down,
    /// since neither event retiles and an app may animate its
    /// show open past the focus report that would have.
    func crossedScreenCover(
        _ event: KiwiEvent,
        before: CGRect?
    ) -> Bool {
        switch event {
        case .windowMoved(_, let after), .windowResized(_, let after):
            guard let before else { return false }
            return coversAScreen(before) != coversAScreen(after)
        default:
            return false
        }
    }
}
