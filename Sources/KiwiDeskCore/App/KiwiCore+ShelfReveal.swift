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
        var indicators:
            [ShelfManager.Key: (spec: ShelfIndicatorSpec, space: Bool)] =
                [:]

        /// Files each hiding bar of `plans` — its target, and its
        /// edge's mark where the edge hides to one.
        @MainActor mutating func file(
            _ plans: [ShelfPlan],
            display: DisplayID,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            reveal: ShelfRevealer,
            gaps: Gaps,
            settings: TilingSettings
        ) {
            for plan in plans {
                let hiding = plan.shelfEdge.bars.keys.filter {
                    plan.shelfEdge.shown($0)?.revealable == true
                }
                guard !hiding.isEmpty else { continue }
                file(
                    plan,
                    bars: Set(hiding),
                    key: ShelfManager.Key(display: display, edge: plan.edge),
                    screen: screen,
                    items: items,
                    reveal: reveal,
                    gaps: gaps,
                    settings: settings
                )
            }
        }

        /// Files one plan's hiding bars and, where its edge hides to
        /// a mark, the mark.
        @MainActor private mutating func file(
            _ plan: ShelfPlan,
            bars: Set<ShelfBar>,
            key: ShelfManager.Key,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            reveal: ShelfRevealer,
            gaps: Gaps,
            settings: TilingSettings
        ) {
            let primary = GeometryUtils.primaryHeight
            let strip = GeometryUtils.flip(plan.strip, primaryHeight: primary)
            let auto = bars.filter { plan.shelfEdge.shown($0) == .auto }
            for bar in bars where !auto.contains(bar) {
                targets[.init(shelf: key, bar: bar)] = ShelfRevealer.Target(
                    edge: plan.edge,
                    strip: strip,
                    screen: screen.frame,
                    band: nil
                )
            }
            guard !auto.isEmpty else { return }
            // The mark draws the shelf as rendered: Reduce
            // transparency makes its fill opaque (#1374).
            let shelf = LiquidGlassGate.rendered(settings.kiwishelf)
            let carriesSpace = auto.contains(.space)
            let mark = Self.mark(items: carriesSpace ? items : nil)
            // The band reaches past the screen side into a menu bar
            // or a Dock, and in to the windows: the sliver's rest and
            // their outer gap (ui-designer, #761).
            let band = ShelfReveal.band(
                of: strip,
                edge: plan.edge,
                outward: shelf.outerMargin + ShelfReveal.overshoot,
                inward: KiwiShelf.hiddenDepth + shelf.innerMargin
                    + Self.outerGap(gaps, on: plan.edge)
            )
            let markIn = ShelfIndicatorSpec.frame(
                of: mark,
                in: plan.strip,
                edge: plan.edge
            )
            let near = GeometryUtils.flip(markIn, primaryHeight: primary)
                .insetBy(
                    dx: -ShelfReveal.nearReach,
                    dy: -ShelfReveal.nearReach
                )
            var shown = true
            var hovered = false
            for bar in auto {
                let barKey = ShelfRevealer.Key(shelf: key, bar: bar)
                targets[barKey] = ShelfRevealer.Target(
                    edge: plan.edge,
                    strip: strip,
                    screen: screen.frame,
                    band: band,
                    near: near
                )
                shown = shown && reveal.reveal(of: barKey).isShown
                hovered = hovered || reveal.arming.contains(barKey)
            }
            indicators[key] = (
                ShelfIndicatorSpec(
                    mark: mark,
                    frame: markIn,
                    horizontal: plan.horizontal,
                    fill: shelf.fillColor,
                    currentInk: shelf.activeItemColor,
                    ink: shelf.idleItemColor,
                    emptyInk: shelf.emptyItemColor,
                    highlight: shelf.highlightColor,
                    shown: shown,
                    hovered: hovered,
                    morphs: shelf.drawsPlate,
                    rimWidth: ShelfIndicatorSpec.rimWidth(for: shelf),
                    sheen: settings.borderStyle.sheen
                ),
                carriesSpace
            )
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

        /// Space dots from the Space Bar's items, else the line.
        static func mark(
            items: [SpaceBarOverlay.Item]?
        ) -> ShelfIndicatorSpec.Mark {
            guard let items else { return .line }
            let dots = items.filter { $0.space != nil }.map {
                ShelfIndicatorSpec.Dot(
                    current: $0.active,
                    occupied: $0.windowCount > 0
                )
            }
            return dots.isEmpty ? .line : .dots(dots)
        }
    }

    /// Hands the pass's hiding bars to the revealer and their marks
    /// to the panels.
    func syncHidingShelves(_ hiding: HidingShelves) {
        shelves.reveal.sync(hiding.targets)
        shelves.indicators.sync(hiding.indicators)
    }

    /// A press on `key`'s mark: one direction for every bar the
    /// pointer can open there.
    func toggleShelfReveal(_ key: ShelfManager.Key) {
        shelves.reveal.toggleShelf(
            key,
            duration: tiler.settings.kiwishelf.revealDuration
        )
    }

    /// The show/hide action on one bar.
    func toggleBarReveal(_ key: ShelfRevealer.Key) {
        shelves.reveal.toggle(
            key,
            duration: tiler.settings.kiwishelf.revealDuration
        )
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
        else { return .fail("the \(name) has nothing to show here") }
        toggleBarReveal(key)
        return .ok()
    }
}
