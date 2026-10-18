import AppKit

extension SpaceBarOverlay.Item {
    /// The windows the Space holds, drawn or collapsed — what a
    /// hidden shelf's Space dot brightens for (#761).
    var windowCount: Int {
        collapse?.windows
            ?? apps.reduce(0) { $0 + $1.count }
            + after.windows.count + before.windows.count
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
        /// each hiding one whose shelf is shown; every hiding plan
        /// files its target and its indicator.
        @MainActor mutating func shown(
            of plans: [ShelfPlan],
            display: DisplayID,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            core: KiwiCore,
            settings: TilingSettings
        ) -> [ShelfPlan] {
            plans.filter { plan in
                guard plan.hides else { return true }
                let key = ShelfManager.Key(display: display, edge: plan.edge)
                let primary = GeometryUtils.primaryHeight
                targets[key] = ShelfRevealer.Target(
                    edge: plan.edge,
                    strip: GeometryUtils.flip(
                        plan.strip,
                        primaryHeight: primary
                    ),
                    screen: screen.frame
                )
                let shown = core.shelves.reveal.reveal(of: key).isShown
                let carriesSpace = plan.arrangement.space != nil
                let mark = Self.mark(
                    items: carriesSpace ? items : nil
                )
                indicators[key] = (
                    ShelfIndicatorSpec(
                        mark: mark,
                        frame: ShelfIndicatorSpec.frame(
                            of: mark,
                            in: plan.strip,
                            edge: plan.edge
                        ),
                        horizontal: plan.horizontal,
                        fill: settings.kiwishelf.fillColor,
                        ink: settings.kiwishelf.itemColor,
                        emptyInk: settings.kiwishelf.emptyItemColor,
                        shown: shown
                    ),
                    carriesSpace
                )
                return shown
            }
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
    /// the action on the shelf the bar sits on, on the screen the
    /// active Space lays out on. Refused where that shelf does not
    /// hide; it never hides an `always` bar.
    func shelfRevealCommand(spaceBar: Bool) -> CommandResponse {
        let workspaces = state.workspaces
        guard
            let space = workspaces.activeSpace,
            let id = workspaces.display(of: space),
            let display = workspaces.allDisplays.first(where: {
                $0.id == id
            })
        else { return .fail("no screen is showing a Space") }
        let shown = tiler.settings.onScreen(display.fingerprint)
        let edge =
            spaceBar ? shown.spaceBarStyle.edge : shown.appBarStyle.edge
        let key = ShelfManager.Key(display: id, edge: edge)
        guard shelves.reveal.targets[key] != nil else {
            let bar = spaceBar ? "Space Bar" : "App Bar"
            return .fail("the \(bar) does not hide on this screen")
        }
        toggleShelfReveal(key)
        return .ok()
    }
}
