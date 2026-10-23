import AppKit

extension SpaceBarOverlay.Item {
    /// The windows the Space holds, by the one count the item's
    /// view announces and inks by (#761).
    var windowCount: Int {
        SpaceBarItemView.heldWindows(
            collapse: collapse,
            apps: apps,
            before: before,
            after: after
        )
    }
}

/// The hiding bars (#761): which bars `updateBars()` draws, what
/// a hiding edge's mark shows, and each bar's shortcut. A reveal
/// redraws the bars and never retiles — an `auto` edge reserves
/// only its constant sliver (`KiwiShelf.hiddenReservation`) and a
/// `hidden` one nothing.
extension KiwiCore {
    /// One `updateBars()` pass's hiding bars, gathered per display
    /// and synced once at its end.
    struct HidingShelves {
        var targets: [ShelfRevealer.Key: ShelfRevealer.Target] = [:]
        var indicators: [ShelfRevealer.Key: ShelfIndicatorSpec] = [:]
        /// The mark each hiding shelf's grow reveal grows out of:
        /// its shown bar's, else its first mark's. AX coordinates.
        var marks: [ShelfManager.Key: CGRect] = [:]
        /// How each of those marks grows past the plain hover, so the
        /// reveal starts from the plate on screen (#2567).
        var markGrowths: [ShelfManager.Key: ShelfIndicatorSpec.Growth] = [:]
        /// Each Space mark's first dot shown, carried from the last
        /// pass so the dots slide only when they must
        /// (`ShelfDotWindow`); a mark that stops drawing forgets it.
        var dotStarts: [ShelfRevealer.Key: Int] = [:]

        /// Files each hiding bar of `plans` — its target, and its
        /// mark where it hides to one.
        @MainActor mutating func file(
            _ plans: [ShelfPlan],
            display: DisplayID,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            appWindows: Int? = nil,
            reveal: ShelfRevealer,
            gaps: Gaps,
            settings: TilingSettings
        ) {
            for plan in plans {
                let hiding = plan.shelfEdge.bars.keys.filter {
                    plan.shelfEdge.shown($0)?.revealable == true
                }
                guard !hiding.isEmpty else { continue }
                fileEdge(
                    plan,
                    bars: Set(hiding),
                    key: ShelfManager.Key(display: display, edge: plan.edge),
                    screen: screen,
                    items: items,
                    appWindows: appWindows,
                    reveal: reveal,
                    gaps: gaps,
                    settings: settings
                )
            }
        }

        /// Files one plan's hiding bars: an `auto` bar's mark, band
        /// and near cue at its place in the edge's row of marks
        /// (`ShelfMarkPlacement`), a `hidden` bar's band-less
        /// target. A hidden bar whose sibling on the edge shows
        /// yields — no band, its mark standing aside — so the
        /// mouse opens one bar at a time (owner, 2026-10-19).
        @MainActor private mutating func fileEdge(
            _ plan: ShelfPlan,
            bars: Set<ShelfBar>,
            key: ShelfManager.Key,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            appWindows: Int?,
            reveal: ShelfRevealer,
            gaps: Gaps,
            settings: TilingSettings
        ) {
            let primary = GeometryUtils.primaryHeight
            let flip = { GeometryUtils.flip($0, primaryHeight: primary) }
            let strip = flip(plan.strip)
            let barKey = { ShelfRevealer.Key(shelf: key, bar: $0) }
            let shown = { reveal.reveal(of: barKey($0)).isShown }
            // Where a shown bar draws: its run inside its slot, never
            // the whole slot, which spans the edge for a lone bar.
            let section = { (bar: ShelfBar) -> CGRect? in
                let slot =
                    bar == .space
                    ? plan.arrangement.space : plan.arrangement.app
                return slot.map { slot in
                    let drawn = plan.needs[bar].map(slot.drawing) ?? slot
                    return flip(plan.segment(drawn))
                }
            }
            // The mark draws the shelf as rendered: Reduce
            // transparency makes its fill opaque (#1374).
            let shelf = LiquidGlassGate.rendered(settings.kiwishelf)
            let auto = ShelfArrangement.ordered(
                bars.filter { plan.shelfEdge.shown($0) == .auto },
                shelf
            )
            for bar in bars where !auto.contains(bar) {
                targets[barKey(bar)] = ShelfRevealer.Target(
                    edge: plan.edge,
                    strip: strip,
                    screen: screen.frame,
                    band: nil,
                    section: section(bar)
                )
            }
            let spans = ShelfMarkPlacement.bands(
                for: Set(auto),
                length: plan.length,
                shelf: shelf
            )
            for (index, bar) in auto.enumerated() {
                guard let span = spans[bar] else { continue }
                let dots =
                    bar == .space
                    ? spaceDots(items, key: barKey(bar), settings: settings)
                    : nil
                let mark = dots?.mark ?? .line
                let markIn = ShelfIndicatorSpec.frame(
                    of: mark,
                    in: plan.strip,
                    edge: plan.edge,
                    centre: (span.lowerBound + span.upperBound) / 2
                )
                // The band reaches past the screen side into a menu
                // bar or a Dock, and in to the windows: the sliver's
                // rest and their outer gap (ui-designer, #761).
                let band = ShelfReveal.band(
                    of: strip,
                    edge: plan.edge,
                    along: flip(Self.span(span, of: plan)),
                    outward: shelf.outerMargin + ShelfReveal.overshoot,
                    inward: KiwiShelf.hiddenDepth + shelf.innerMargin
                        + Self.outerGap(gaps, on: plan.edge)
                )
                // Near the mark lights its cue, cut where its band
                // meets a sibling's so one mark lights at a time.
                let near = flip(
                    Self.near(
                        markIn,
                        between: index > 0 ? span.lowerBound : nil,
                        and: index < auto.count - 1 ? span.upperBound : nil,
                        of: plan
                    )
                )
                targets[barKey(bar)] = ShelfRevealer.Target(
                    edge: plan.edge,
                    strip: strip,
                    screen: screen.frame,
                    band: band,
                    near: near,
                    section: section(bar)
                )
                // A grow reveal grows out of the leading shown bar's
                // mark, else the leading mark.
                if marks[key] == nil
                    || (shown(bar)
                        && !auto.prefix(index).contains(where: shown))
                {
                    marks[key] = markIn
                }
                var spec = ShelfIndicatorSpec(
                    mark: mark,
                    frame: markIn,
                    edge: plan.edge,
                    fill: shelf.fillColor,
                    currentInk: shelf.activeItemColor,
                    ink: shelf.idleItemColor,
                    emptyInk: shelf.emptyItemColor,
                    highlight: shelf.highlightColor,
                    shown: shown(bar),
                    hovered: reveal.arming.contains(barKey(bar)),
                    reveal: BarMotion.RevealKind(shelf),
                    rimWidth: ShelfIndicatorSpec.rimWidth(for: shelf),
                    sheen: settings.borderStyle.sheen,
                    yields: reveal.yields(barKey(bar)),
                    label: plan.horizontal ? dots?.label : nil,
                    position: dots?.position,
                    glass: shelf.glassEnabled
                )
                if bar == .app, let appWindows {
                    spec.count = ShelfIndicatorSpec.count(
                        appWindows,
                        font: Self.markCountFont(settings),
                        edge: plan.edge,
                        pillDepth: spec.pillDepth
                    )
                }
                if marks[key] == markIn { markGrowths[key] = spec.growth }
                indicators[barKey(bar)] = spec
            }
        }

        /// `span`, an offset range along `plan`'s edge, as a rect
        /// across the plan's strip (AX).
        static func span(
            _ span: ClosedRange<CGFloat>,
            of plan: ShelfPlan
        ) -> CGRect {
            ShelfArrangement.Slot(
                offset: span.lowerBound,
                length: span.upperBound - span.lowerBound,
                alignment: .center
            ).rect(in: plan.strip, horizontal: plan.horizontal)
        }

        /// The mark's near cue: `nearReach` around it, cut along the
        /// edge at `lead` and `trail` — offsets where its band meets
        /// a sibling's. AX coordinates.
        static func near(
            _ mark: CGRect,
            between lead: CGFloat?,
            and trail: CGFloat?,
            of plan: ShelfPlan
        ) -> CGRect {
            var near = mark.insetBy(
                dx: -ShelfReveal.nearReach,
                dy: -ShelfReveal.nearReach
            )
            let origin = plan.horizontal ? plan.strip.minX : plan.strip.minY
            let low = lead.map { origin + $0 } ?? -.greatestFiniteMagnitude
            let high = trail.map { origin + $0 } ?? .greatestFiniteMagnitude
            if plan.horizontal {
                let minX = max(near.minX, low)
                near = CGRect(
                    x: minX,
                    y: near.minY,
                    width: min(near.maxX, high) - minX,
                    height: near.height
                )
            } else {
                let minY = max(near.minY, low)
                near = CGRect(
                    x: near.minX,
                    y: minY,
                    width: near.width,
                    height: min(near.maxY, high) - minY
                )
            }
            return near
        }

        /// The windows' outer gap on `edge`.
        static func outerGap(_ gaps: Gaps, on edge: AppBarEdge) -> CGFloat {
            switch edge {
            case .top: return gaps.outer.top
            case .bottom: return gaps.outer.bottom
            case .left: return gaps.outer.left
            case .right: return gaps.outer.right
            }
        }
    }

    /// Hands the pass's hiding bars to the revealer and their marks
    /// to the panels.
    func syncHidingShelves(_ hiding: HidingShelves) {
        shelves.reveal.sync(hiding.targets)
        shelves.indicators.dotStarts = hiding.dotStarts
        shelves.indicators.sync(hiding.indicators)
    }

    /// The show/hide action on one bar; false where the revealer
    /// refused it — a bar the tour holds shown (#2515).
    @discardableResult
    func toggleBarReveal(_ key: ShelfRevealer.Key) -> Bool {
        let was = shelves.reveal.reveal(of: key)
        guard
            shelves.reveal.toggle(
                key,
                duration: tiler.settings.kiwishelf.revealTimeout
            )
        else { return false }
        // One line per toggle: a reveal leaves no other trace.
        onLog(
            "shelf reveal: \(key.bar) \(was) → "
                + "\(shelves.reveal.reveal(of: key))"
        )
        return true
    }

    /// `space_bar.toggle_reveal` / `app_bar.toggle_reveal` (#761):
    /// shows or hides the bar on the screen the active Space lays
    /// out on, over the windows, and only that bar. A bar set to
    /// `always` is refused with a pill on the bar, since it is
    /// already shown; the App Bar is refused where the active
    /// Space's layout carries none.
    func shelfRevealCommand(_ bar: ShelfBar) -> CommandResponse {
        let name = bar == .space ? "Space Bar" : "App Bar"
        let workspaces = state.workspaces
        guard let space = workspaces.activeSpace,
            let display = workspaces.display(of: space)
        else { return .fail("the \(name) draws on no screen here") }
        let mode = workspaces[space]?.mode ?? .bsp
        let settings = tiler.settings
        guard bar == .space || settings.appBarVisibility(in: mode) != nil
        else {
            cueRevealRefusal(.noAppBarHere, display: display)
            return .fail("no App Bar in this layout")
        }
        guard settings.revealActionLive(bar, in: mode) else {
            cueRevealRefusal(.alwaysShown(bar), display: display)
            return .fail("the \(name) is set to always")
        }
        // The edge's own fold answers whether the bar hides here: an
        // `auto` bar beside an `always` one reads `always` (#761).
        if settings.autoReadsAlways(
            bar,
            in: mode,
            on: screenFingerprint(of: display)
        ) {
            cueRevealRefusal(.shownBesideAlways(bar), display: display)
            return .fail("the \(name) is shown beside an always bar")
        }
        guard
            let key = shelves.reveal.targets.keys.first(where: {
                $0.shelf.display == display && $0.bar == bar
            })
        else {
            cueRevealRefusal(.nothingToShow(bar), display: display)
            return .fail("the \(name) has nothing to show here")
        }
        guard toggleBarReveal(key) else {
            return .fail("the \(name) is held shown by the tour")
        }
        return .ok()
    }
}
