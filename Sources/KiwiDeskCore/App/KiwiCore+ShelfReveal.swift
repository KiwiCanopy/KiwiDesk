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

/// The hiding shelves (#761): which plans `updateBars()` draws,
/// what a hidden shelf's indicator shows, and the show/hide
/// action. A reveal redraws the bars and never retiles — a hiding
/// edge reserves nothing (`TilingSettings.barEdges(space:app:)`).
extension KiwiCore {
    /// One `updateBars()` pass's hiding shelves, gathered per
    /// display and synced once at its end.
    struct HidingShelves {
        var targets: [ShelfManager.Key: ShelfRevealer.Target] = [:]
        var indicators:
            [ShelfManager.Key: (spec: ShelfIndicatorSpec, space: Bool)] =
                [:]

        /// The plans to draw: every plan that does not hide, and
        /// each hiding one `reveal` shows; every hiding plan files
        /// its target, its bars and its indicator.
        @MainActor mutating func shown(
            of plans: [ShelfPlan],
            display: DisplayID,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            reveal: ShelfRevealer,
            settings: TilingSettings
        ) -> [ShelfPlan] {
            var drawn: [ShelfPlan] = []
            for plan in plans {
                guard plan.hides else {
                    drawn.append(plan)
                    continue
                }
                let key = ShelfManager.Key(display: display, edge: plan.edge)
                let shown = reveal.reveal(of: key).isShown
                file(
                    plan,
                    key: key,
                    screen: screen,
                    items: items,
                    shown: shown,
                    settings: settings
                )
                if shown { drawn.append(plan) }
            }
            return drawn
        }

        /// Files one hiding plan's target, bars and indicator.
        @MainActor private mutating func file(
            _ plan: ShelfPlan,
            key: ShelfManager.Key,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            shown: Bool,
            settings: TilingSettings
        ) {
            let carriesSpace = plan.arrangement.space != nil
            var bars: Set<ShelfBar> = []
            if carriesSpace { bars.insert(.space) }
            if plan.arrangement.app != nil { bars.insert(.app) }
            targets[key] = ShelfRevealer.Target(
                edge: plan.edge,
                strip: GeometryUtils.flip(
                    plan.strip,
                    primaryHeight: GeometryUtils.primaryHeight
                ),
                screen: screen.frame,
                bars: bars
            )
            let shelf = settings.kiwishelf
            let mark = Self.mark(items: carriesSpace ? items : nil)
            indicators[key] = (
                ShelfIndicatorSpec(
                    mark: mark,
                    frame: ShelfIndicatorSpec.frame(
                        of: mark,
                        in: plan.strip,
                        edge: plan.edge
                    ),
                    horizontal: plan.horizontal,
                    fill: shelf.fillColor,
                    currentInk: shelf.activeItemColor,
                    ink: shelf.idleItemColor,
                    emptyInk: shelf.emptyItemColor,
                    shown: shown
                ),
                carriesSpace
            )
        }

        /// Space dots from the Space Bar's items, else the pill.
        static func mark(
            items: [SpaceBarOverlay.Item]?
        ) -> ShelfIndicatorSpec.Mark {
            guard let items else { return .pill }
            let dots = items.filter { $0.space != nil }.map {
                ShelfIndicatorSpec.Dot(
                    current: $0.active,
                    occupied: $0.windowCount > 0
                )
            }
            return dots.isEmpty ? .pill : .dots(dots)
        }
    }

    /// Hands the pass's hiding shelves to the revealer and their
    /// indicators to the panels.
    func syncHidingShelves(_ hiding: HidingShelves) {
        shelves.reveal.sync(hiding.targets)
        shelves.indicators.sync(hiding.indicators)
    }

    /// The show/hide action on `key`'s shelf.
    func toggleShelfReveal(_ key: ShelfManager.Key) {
        shelves.reveal.toggle(
            key,
            duration: tiler.settings.kiwishelf.revealDuration
        )
    }

    /// `space_bar.toggle_reveal` / `app_bar.toggle_reveal` (#761):
    /// the action on the hiding shelf that carries the bar, on the
    /// screen the active Space lays out on. Refused where the bar
    /// reads `always` — it never hides an `always` bar — or draws
    /// on no hiding shelf there.
    func shelfRevealCommand(_ bar: ShelfBar) -> CommandResponse {
        let name = bar == .space ? "Space Bar" : "App Bar"
        guard tiler.settings.visibility(of: bar) == .auto else {
            return .fail("the \(name) does not hide")
        }
        let workspaces = state.workspaces
        guard
            let space = workspaces.activeSpace,
            let display = workspaces.display(of: space),
            let key = shelves.reveal.targets.first(where: {
                $0.key.display == display && $0.value.bars.contains(bar)
            })?.key
        else { return .fail("the \(name) draws on no screen here") }
        toggleShelfReveal(key)
        return .ok()
    }
}
