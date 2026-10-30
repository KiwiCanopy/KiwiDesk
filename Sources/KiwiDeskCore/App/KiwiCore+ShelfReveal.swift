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
        var handles: [ShelfRevealer.Key: ShelfHandleSpec] = [:]
        /// The handle each hiding shelf's grow reveal grows out of —
        /// its shown bar's, else its first — with its growth, so the
        /// reveal starts from the plate on screen (#2567). AX
        /// coordinates.
        var marks: [ShelfManager.Key: BarMotion.RevealMark] = [:]
        /// Each Space mark's first dot shown, carried from the last
        /// pass so the dots slide only when they must
        /// (`ShelfDotWindow`); a mark that stops drawing forgets it.
        var dotStarts: [ShelfRevealer.Key: Int] = [:]
        /// The pocket handle's band on each display's edge of Auto
        /// marks, AX along the edge (#2678): its place in the row.
        var pocketBands: [DisplayID: ClosedRange<CGFloat>] = [:]

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
            let slotOf = { (bar: ShelfBar) in
                bar == .space ? plan.arrangement.space : plan.arrangement.app
            }
            // The pocket's slot holds the bar beside it, never one a
            // sibling's strip lies between (#2678).
            var pocketBar: ShelfBar?
            if let pocket = plan.arrangement.pocket {
                var nearest = CGFloat.greatestFiniteMagnitude
                for bar in [ShelfBar.space, .app] {
                    guard let slot = slotOf(bar) else { continue }
                    let mid: CGFloat = slot.offset + slot.length / 2
                    let distance: CGFloat = abs(mid - pocket.offset)
                    if distance < nearest {
                        nearest = distance
                        pocketBar = bar
                    }
                }
            }
            let section = { (bar: ShelfBar) -> CGRect? in
                slotOf(bar).map { slot in
                    let drawn = plan.needs[bar].map(slot.drawing) ?? slot
                    let run = plan.segment(drawn)
                    guard bar == pocketBar,
                        let pocket = plan.arrangement.pocket
                    else { return flip(run) }
                    return flip(run.union(plan.segment(pocket)))
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
            // The handle stands where the shown pocket does (#2678).
            let pocketSlot = plan.arrangement.pocket.map {
                $0.offset...($0.offset + $0.length)
            }
            let row = ShelfMarkPlacement.row(
                for: Set(auto),
                pocket: plan.carriesPocket && !auto.isEmpty
                    ? pocketSlot : nil,
                length: plan.length,
                shelf: shelf
            )
            let spans = row.bars
            if let band = row.pocket {
                let origin =
                    plan.horizontal ? plan.strip.minX : plan.strip.minY
                pocketBands[key.display] =
                    (origin + band.lowerBound)...(origin + band.upperBound)
            }
            for (index, bar) in auto.enumerated() {
                guard let span = spans[bar] else { continue }
                let dots =
                    bar == .space
                    ? spaceDots(items, key: barKey(bar), settings: settings)
                    : nil
                let mark = dots?.mark ?? .line
                let markIn = ShelfHandleSpec.frame(
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
                // handle, else the leading handle.
                let leads =
                    marks[key] == nil
                    || (shown(bar)
                        && !auto.prefix(index).contains(where: shown))
                var spec = ShelfHandleSpec(
                    mark: mark,
                    frame: markIn,
                    edge: plan.edge,
                    fill: shelf.glassFill,
                    currentInk: shelf.activeItemColor,
                    ink: shelf.idleItemColor,
                    emptyInk: shelf.emptyItemColor,
                    highlight: shelf.highlightColor,
                    shown: shown(bar),
                    hovered: reveal.arming.contains(barKey(bar)),
                    reveal: BarMotion.RevealKind(shelf),
                    rimWidth: ShelfHandleSpec.rimWidth(for: shelf),
                    sheen: settings.borderStyle.sheen,
                    yields: reveal.yields(barKey(bar)),
                    label: plan.horizontal ? dots?.label : nil,
                    position: dots?.position,
                    glass: shelf.glassEnabled
                )
                if bar == .app, let appWindows {
                    spec.count = ShelfHandleSpec.count(
                        appWindows,
                        font: Self.markCountFont(settings),
                        edge: plan.edge,
                        pillDepth: spec.pillDepth
                    )
                }
                if leads {
                    marks[key] = .init(frame: markIn, growth: spec.growth)
                }
                handles[barKey(bar)] = spec
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
