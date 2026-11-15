import Foundation

/// Monocle's "Maximize windows" (#2976): gaps 0, both bars read as
/// Hidden and the pocket resting nowhere in that layout, never a
/// stand-down (`docs/design-decisions.md`, bars.md).
extension TilingSettings {
    /// Whether a Space laid out in `mode` maximizes every window.
    public func maximizesWindows(in mode: LayoutMode) -> Bool {
        mode == .monocle && monocle.maximizeWindows
    }

    /// The bars' visibility a Space laid out in `mode` reads: each
    /// bar's own, or Hidden for both where `mode` maximizes its
    /// windows; the App Bar nil where the layout carries none.
    public func barVisibilities(
        in mode: LayoutMode
    ) -> (space: ShelfVisibility, app: ShelfVisibility?) {
        let app = appBarVisibility(in: mode)
        guard maximizesWindows(in: mode) else {
            return (spaceBarStyle.visibility, app)
        }
        return (.hidden, app.map { _ in .hidden })
    }

    /// Whether the edge reveal is live over a maximized window
    /// (#3346 ▸ 4): `maximized_visibility` reads Auto. The leaf's one
    /// reader; the revealer's answers below derive from it, and
    /// `layoutBounds` never asks, since every bar still reads Hidden.
    public var maximizedRevealLive: Bool {
        kiwishelf.maximizedVisibility == .auto
    }

    /// The bars a pointer resting at their edge brings in over a
    /// maximized window in `mode` (#3346): none while the reveal is
    /// not live, else each bar whose stored visibility shows
    /// unprompted, so a stored Hidden bar stays Hidden.
    public func maximizedHoverBars(in mode: LayoutMode) -> Set<ShelfBar> {
        guard maximizedRevealLive else { return [] }
        var bars: Set<ShelfBar> = []
        if spaceBarStyle.visibility.showsUnprompted { bars.insert(.space) }
        if appBarVisibility(in: mode)?.showsUnprompted == true {
            bars.insert(.app)
        }
        return bars
    }

    /// Whether `maximized_visibility` could reveal anything (#3346 ▸
    /// 9): the Space Bar, some layout's App Bar or the Pocket is
    /// stored to show unprompted. What Settings asks to grey its row.
    public var maximizedRevealsAnything: Bool {
        spaceBarStyle.visibility.showsUnprompted
            || kiwishelf.pocketVisibility.showsUnprompted
            || LayoutMode.allCases.contains {
                appBarVisibility(in: $0)?.showsUnprompted == true
            }
    }

    /// Whether the Pocket comes in with a revealed bar over a
    /// maximized window (#3346 ▸ 8): Auto, and its stored Show is not
    /// Hidden. It never rests there.
    public var maximizedPocketRides: Bool {
        maximizedRevealLive && kiwishelf.pocketVisibility.showsUnprompted
    }

    /// These settings with every bar and the Pocket set to Hidden in
    /// every layout: what a tiling-off Space whose tick hides the
    /// bars draws (#3151).
    public func hidingEveryBar() -> TilingSettings {
        var out = self
        out.spaceBarStyle.visibility = .hidden
        for mode in LayoutMode.allCases {
            guard let path = Self.appBarPath(for: mode) else { continue }
            out[keyPath: path].visibility = .hidden
        }
        out.kiwishelf.pocketVisibility = .hidden
        return out
    }

    /// `barEdges(space:app:)` over the visibilities `mode` reads.
    public func barEdges(in mode: LayoutMode) -> [ShelfEdge] {
        let shown = barVisibilities(in: mode)
        return barEdges(space: shown.space, app: shown.app)
    }

    /// The gaps `space`'s layout input takes: none where its layout
    /// maximizes its windows, else the Space's own.
    public func layoutGaps(for space: Space) -> Gaps {
        maximizesWindows(in: space.mode) ? .none : gaps(for: space.id)
    }

    /// Whether the pocket rests on screen in `mode`: its Show is not
    /// Hidden and `mode` does not maximize its windows, where a
    /// handle at rest would sit on the window (#2976 ▸ 4).
    public func pocketRests(in mode: LayoutMode) -> Bool {
        pocketRests && !maximizesWindows(in: mode)
    }
}

extension Gaps {
    /// No gap anywhere: what a window filling its screen takes.
    public static let none = Gaps(
        outer: .init(top: 0, bottom: 0, left: 0, right: 0),
        inner: .init(horizontal: 0, vertical: 0)
    )
}
