import AppKit

/// A window covering an entire screen edge for edge — a slide
/// show, a borderless-fullscreen game or player — is PRESENTING
/// there (#1787): the float fit and the gather leave it where its
/// app put it, and the shelf stands down behind it. Judged on the
/// frame and the window's subrole (#1788); the residues are the
/// design entry's.
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

    /// Whether `window` may present at all: a titled window reads
    /// `AXStandardWindow` (a float maximised by Fill under an
    /// auto-hiding menu bar), a show or a borderless game does
    /// not — PowerPoint's show reads `AXUnknown` (device,
    /// 2026-10-11). An unread subrole keeps the frame verdict.
    nonisolated static func mayPresent(_ window: ManagedWindow) -> Bool {
        window.subrole != kAXStandardWindowSubrole
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

    /// Whether `window` at `frame` (AX) covers a screen AS A
    /// SHOW: the frame verdict and `mayPresent` together, the one
    /// composition a caller judging a candidate frame takes
    /// (#1788), its float ruling already made.
    func coversAsShow(_ window: ManagedWindow, at frame: CGRect) -> Bool {
        Self.mayPresent(window) && coversAScreen(frame)
    }

    /// Whether window `id` at `frame` (AX) is PRESENTING — the
    /// one door a reader of a tracked window asks (#1788): an
    /// EFFECTIVE float, never a tiled slot a gapless layout may
    /// size to a screen, and never native fullscreen, which its
    /// own exemption owns. Ruled onto it: the focus ring, the
    /// on-window marks and the #1161 placement bounce
    /// (`PresentingReaderTests`), and `explain_window` reports it
    /// (#1685). A raw `covers` /
    /// `coversAScreen` caller is a register entry in
    /// `ScreenCoveringCallerCensusTests`. Ruled to STAY on
    /// native fullscreen's skips alone: the inactive-Space
    /// stash, focus stepping and the sticky carry (owner,
    /// 2026-10-11) — a show is on the Desktop the user sees.
    func presents(_ id: WindowID, at frame: CGRect) -> Bool {
        guard let window = state.windows[id], !window.isFullscreen,
            EffectiveFloat.applies(
                isFloating: window.isFloating,
                mode: state.workspaces.space(of: id).flatMap {
                    state.workspaces[$0]?.mode
                }
            )
        else { return false }
        return coversAsShow(window, at: frame)
    }

    /// Whether the shelf stands down on `display`: a native
    /// fullscreen Space (#670), a presentation in front, or the
    /// Space it shows holding a maximized window (#2448). Both
    /// bars ask this one answer.
    func shelfStandsDown(on display: DisplayID) -> Bool {
        !NativeSpaces.currentSpaceIsUser(display: display)
            || showsPresentation(on: display)
            || showsMaximized(on: display)
    }

    /// Whether the Space `display` shows holds a maximized window.
    func showsMaximized(on display: DisplayID) -> Bool {
        guard let id = state.workspaces.activeSpace(on: display),
            let space = state.workspaces[id]
        else { return false }
        return state.maximizedWindow(of: space) != nil
    }

    /// The same answer for a GUI surface on `screen` — the
    /// slow-boot notice (#1715).
    public func shelfStandsDown(on screen: NSScreen) -> Bool {
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
    private func showsPresentation(on display: DisplayID) -> Bool {
        guard let screen = TilingEngine.screen(for: display)
        else { return false }
        let bounds = Self.axFrame(of: screen)
        guard
            state.windows.all.contains(where: {
                Self.mayPresent($0) && Self.covers($0.frame, bounds)
            }),
            let front = Self.normalFrames(of: frontStack()).first(where: {
                bounds.contains(CGPoint(x: $0.midX, y: $0.midY))
            })
        else { return false }
        return Self.covers(front, bounds)
    }

    /// One window of the front-to-back read.
    typealias FrontWindow = FloatDetection.ListedWindow

    /// Every visible window front to back, any layer, KiwiDesk's
    /// own windows INCLUDED, the desktop's elements left out — the
    /// live default of `frontStack` (#1788, #1869); a consumer
    /// filters what it needs. KiwiVision reads the other way,
    /// through `liveFrontWindows`.
    static func liveFrontStack() -> [FrontWindow] {
        FloatDetection.frontToBackWindows { _, _ in false }
    }

    /// `stack` without KiwiDesk's chrome: no overlay is ever a
    /// presentation or a masked window, and a moving ring's panel
    /// spans its screen (#1937).
    static func withoutOwnChrome(
        _ stack: [FrontWindow]
    ) -> [FrontWindow] {
        let own = getpid()
        return stack.filter {
            !($0.pid == own
                && EventLoop.isOwnChrome(number: Int($0.number)))
        }
    }

    /// The stack without KiwiDesk's chrome — KiwiVision's mask
    /// reads it (#2103). It keeps the desktop's elements: macOS
    /// counts a below-normal bar such as SketchyBar's among them,
    /// and Never dimmed must see it to keep it clear; the mask walk
    /// drops the wallpaper and the icons by layer.
    static func liveFrontWindows() -> [FrontWindow] {
        withoutOwnChrome(
            FloatDetection.frontToBackWindows(
                includingDesktopElements: true
            ) { _, _ in false }
        )
    }

    /// The normal-layer frames of `stack` — which window a screen
    /// SHOWS in front.
    static func normalFrames(
        of stack: [FrontWindow]
    ) -> [CGRect] {
        withoutOwnChrome(stack).filter { $0.layer == 0 }.map(\.frame)
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
