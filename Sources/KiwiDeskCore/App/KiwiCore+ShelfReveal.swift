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

/// The hiding bars (#761, #3349): which bars `updateBars()` draws,
/// each Auto bar's handle along its run and its approach, and each
/// bar's shortcut. A reveal redraws the bars and never retiles — a
/// handle reserves nothing.
extension KiwiCore {
    /// One `updateBars()` pass's hiding bars, gathered per display
    /// and synced once at its end.
    struct HidingShelves {
        var targets: [ShelfRevealer.Key: ShelfRevealer.Target] = [:]
        var handles: [ShelfRevealer.Key: ShelfHandleSpec] = [:]
        /// The handle each hiding shelf's grow reveal grows out of —
        /// its shown bar's, else its first — so the reveal starts
        /// from the handle on screen (#2567). AX coordinates.
        var marks: [ShelfManager.Key: BarMotion.RevealMark] = [:]
        /// Each Space handle's first dot shown, carried from the
        /// last pass so the dots slide only when they must
        /// (`ShelfDotWindow`); a handle that stops drawing forgets
        /// it.
        var dotStarts: [ShelfRevealer.Key: Int] = [:]
        /// The pocket handle's band on each display's Auto edge, AX
        /// along the edge (#2678): where the shown pocket stands.
        var pocketBands: [DisplayID: ClosedRange<CGFloat>] = [:]

        /// Files each hiding bar of `plans` — its target, and its
        /// handle where it hides to one. `hover` names the bars a
        /// maximized window's screen brings in (#3346), which rest
        /// as a handle there too (#3349 rule 7).
        @MainActor mutating func file(
            _ plans: [ShelfPlan],
            display: DisplayID,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            appIcons: [NSImage] = [],
            screens: [CGRect],
            reveal: ShelfRevealer,
            hover: Set<ShelfBar> = [],
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
                    appIcons: appIcons,
                    screens: screens,
                    reveal: reveal,
                    hover: hover,
                    settings: settings
                )
            }
        }

        /// Files one plan's hiding bars: an Auto bar's handle along
        /// its run and its approach, a `hidden` bar's target with no
        /// approach. A hidden bar whose sibling on the edge shows
        /// yields — its approach opens nothing, its handle standing
        /// aside — so the mouse opens one bar at a time (owner,
        /// 2026-10-19).
        @MainActor private mutating func fileEdge(
            _ plan: ShelfPlan,
            bars: Set<ShelfBar>,
            key: ShelfManager.Key,
            screen: NSScreen,
            items: [SpaceBarOverlay.Item]?,
            appIcons: [NSImage],
            screens: [CGRect],
            reveal: ShelfRevealer,
            hover: Set<ShelfBar>,
            settings: TilingSettings
        ) {
            let primary = GeometryUtils.primaryHeight
            let flip = { GeometryUtils.flip($0, primaryHeight: primary) }
            let strip = flip(plan.strip)
            let barKey = { ShelfRevealer.Key(shelf: key, bar: $0) }
            let shown = { reveal.reveal(of: barKey($0)).isShown }
            // Where each bar draws once revealed, so a hidden bar's
            // handle runs along it (#3349).
            let placed = plan.revealed ?? (plan.arrangement, plan.needs)
            let slotOf = { (bar: ShelfBar) in
                bar == .space
                    ? placed.arrangement.space : placed.arrangement.app
            }
            // The bar's run inside its slot, never the whole slot,
            // which spans the edge for a lone bar (AX).
            let run = { (bar: ShelfBar) -> CGRect? in
                slotOf(bar).map { slot in
                    plan.segment(placed.needs[bar].map(slot.drawing) ?? slot)
                }
            }
            // The pocket's slot holds the bar beside it, never one a
            // sibling's strip lies between (#2678): its section
            // spans the pocket too.
            let pocketBar = Self.pocketBar(of: placed.arrangement)
            let section = { (bar: ShelfBar) -> CGRect? in
                run(bar).map { run in
                    guard bar == pocketBar,
                        let pocket = placed.arrangement.pocket
                    else { return flip(run) }
                    return flip(run.union(plan.segment(pocket)))
                }
            }
            // The handle draws the shelf as rendered: Reduce
            // transparency makes its fill opaque (#1374).
            let shelf = LiquidGlassGate.rendered(settings.kiwishelf)
            let handled = ShelfArrangement.ordered(
                bars.filter {
                    plan.shelfEdge.shown($0) == .auto || hover.contains($0)
                },
                shelf
            )
            for bar in bars where !handled.contains(bar) {
                targets[barKey(bar)] = ShelfRevealer.Target(
                    edge: plan.edge,
                    strip: strip,
                    screen: screen.frame,
                    approach: nil,
                    section: section(bar)
                )
            }
            // The pocket's handle stands where the shown pocket does
            // (#2678).
            if plan.carriesPocket, !handled.isEmpty,
                let pocket = plan.arrangement.pocket
            {
                let band = ShelfMarkPlacement.pocketBand(
                    slot: pocket.offset...(pocket.offset + pocket.length),
                    length: plan.length
                )
                let origin =
                    plan.horizontal ? plan.strip.minX : plan.strip.minY
                pocketBands[key.display] =
                    (origin + band.lowerBound)...(origin + band.upperBound)
            }
            let side = Self.side(of: plan.strip, edge: plan.edge, shelf: shelf)

            for (index, bar) in handled.enumerated() {
                guard let run = run(bar) else { continue }
                let dots =
                    bar == .space
                    ? spaceDots(items, key: barKey(bar)) : nil
                let peek = dots?.peek ?? .glyphs(appIcons)
                var spec = ShelfHandleSpec(
                    peek: peek,
                    frame: ShelfHandleSpec.frame(
                        along: run,
                        edge: plan.edge,
                        side: side
                    ),
                    edge: plan.edge,
                    fill: shelf.glassFill,
                    currentInk: shelf.activeItemColor,
                    ink: shelf.idleItemColor,
                    emptyInk: shelf.emptyItemColor,
                    shown: shown(bar),
                    hovered: reveal.arming.contains(barKey(bar)),
                    reveal: BarMotion.RevealKind(shelf)
                )
                spec.yields = reveal.yields(barKey(bar))
                spec.position = dots?.position
                spec.glass = shelf.glassEnabled
                targets[barKey(bar)] = Self.target(
                    spec,
                    side: side,
                    strip: strip,
                    screen: screen.frame,
                    // An edge another screen continues past is a
                    // crossing: a push there opens nothing (#3349).
                    beyond: Self.continues(
                        plan.edge,
                        of: screen.frame,
                        along: flip(run),
                        among: screens
                    ),
                    section: section(bar),
                    maximized: hover.contains(bar),
                    cut: (
                        lead: index > 0,
                        trail: index < handled.count - 1
                    )
                )
                // A grow reveal grows out of the leading shown bar's
                // handle, else the leading handle.
                if marks[key] == nil
                    || (shown(bar)
                        && !handled.prefix(index).contains(where: shown))
                {
                    marks[key] = .init(frame: spec.grown)
                }
                handles[barKey(bar)] = spec
            }
        }
    }

    /// Hands the pass's hiding bars to the revealer and their marks
    /// to the panels.
    func syncHidingShelves(_ hiding: HidingShelves) {
        shelves.reveal.sync(hiding.targets)
        shelves.handles.dotStarts = hiding.dotStarts
        shelves.handles.sync(hiding.handles)
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
}
