import AppKit

/// Each display's shelf plans (#1517, #1731): one per edge a
/// shown bar sits on, its strip measured by `ShelfGeometry.strips`
/// and its bars placed along it by `ShelfArrangement`.
extension KiwiCore {
    /// One shelf: its edge, its strip in AX coordinates and each
    /// bar's slot along it.
    struct ShelfPlan {
        let edge: AppBarEdge
        let strip: CGRect
        let horizontal: Bool
        /// The edge's bars and their visibility (#761).
        let shelfEdge: ShelfEdge
        /// The arrangement and natural run lengths of every bar
        /// resting on the edge (`ShelfEdge.resting`): where a
        /// handle runs, its bar lands and a shown bar is held — one
        /// arrangement for all three (#3349, #3359).
        let resting:
            (
                arrangement: ShelfArrangement,
                needs: [ShelfBar: CGFloat]
            )
        /// The bars drawn this pass, each in its resting slot.
        let drawn: Set<ShelfBar>
        /// Whether the pocket stands on this edge this pass — the
        /// one answer its slot, its Auto mark band and the reveal
        /// target read (#2678).
        var carriesPocket = false

        /// A plan over `arrangement`, the resting bars', drawing
        /// `drawn` — every bar it places unless named.
        init(
            edge: AppBarEdge,
            strip: CGRect,
            horizontal: Bool,
            arrangement: ShelfArrangement,
            shelfEdge: ShelfEdge,
            needs: [ShelfBar: CGFloat] = [:],
            drawn: Set<ShelfBar>? = nil,
            carriesPocket: Bool = false
        ) {
            self.edge = edge
            self.strip = strip
            self.horizontal = horizontal
            self.shelfEdge = shelfEdge
            self.resting = (arrangement, needs)
            self.drawn =
                drawn
                ?? Set(
                    [
                        arrangement.space.map { _ in ShelfBar.space },
                        arrangement.app.map { _ in ShelfBar.app },
                    ].compactMap { $0 }
                )
            self.carriesPocket = carriesPocket
        }

        /// The drawn bars' slots of the resting arrangement.
        var arrangement: ShelfArrangement {
            resting.arrangement.keeping(drawn)
        }
        /// Each drawn bar's natural run length, which its slot
        /// draws in (`ShelfArrangement.Slot.drawing`).
        var needs: [ShelfBar: CGFloat] {
            resting.needs.filter { drawn.contains($0.key) }
        }

        /// Whether the edge hides to a mark (#761).
        var hides: Bool { shelfEdge.hides }
        /// Whether a reveal here comes onto an empty edge, so the
        /// shelf slides or grows rather than joins (#2497).
        var slides: Bool { shelfEdge.drawsNothingAtRest }
        /// Whether the plan places any bar this pass.
        var drawsAny: Bool {
            arrangement.space != nil || arrangement.app != nil
        }

        /// The strip's length along the edge.
        var length: CGFloat {
            horizontal ? strip.width : strip.height
        }

        func segment(_ slot: ShelfArrangement.Slot) -> CGRect {
            slot.rect(in: strip, horizontal: horizontal)
        }
    }

    /// Places the bars on the shelves of a screen whose visible
    /// frame is `visible` — the screen's, never the layout bounds,
    /// which the shelves have already left. One plan per edge a bar
    /// sits on — one while the bars share an edge, one per bar while
    /// they are split (#1731), the Space Bar's first
    /// (`ShelfGeometry.strips`) — placing only the bars `drawn`
    /// answers for that edge (#761): the ones shown at rest and the
    /// ones a reveal shows, read in `mode`, the layout the screen
    /// shows. Each drawn bar stands in its slot of the bars
    /// resting on the edge, `hover` the bars a maximized window's
    /// screen brings in (#3359). A plan that draws nothing still
    /// carries its strip, where a hidden bar's shortcut would show
    /// it.
    func shelfPlans(
        visible: CGRect,
        settings: TilingSettings,
        mode: LayoutMode,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?,
        pocket: Bool,
        hover: Set<ShelfBar>,
        drawn: (ShelfEdge) -> Set<ShelfBar>
    ) -> [ShelfPlan] {
        // The bars as the screen's shown layout reads them (#2976).
        let shown = settings.barVisibilities(in: mode)
        let folded = settings.barEdges(
            space: spaceItems != nil ? shown.space : nil,
            app: app != nil ? shown.app : nil
        )
        let strips = ShelfGeometry.strips(
            in: visible,
            edges: folded.map(\.edge),
            shelf: settings.kiwishelf
        )
        return zip(folded, strips).map { shelfEdge, strip in
            let edge = shelfEdge.edge
            let place = { (bars: Set<ShelfBar>, shown: Set<ShelfBar>) in
                self.shelfPlan(
                    edge: shelfEdge,
                    strip: strip,
                    settings: settings,
                    spaceItems: settings.spaceBarStyle.edge == edge
                        && bars.contains(.space) ? spaceItems : nil,
                    app: settings.appBarStyle.edge == edge
                        && bars.contains(.app) ? app : nil,
                    pocket: pocket && edge == settings.kiwishelf.pocketEdge,
                    drawn: shown
                )
            }
            let bars = drawn(shelfEdge)
            return place(
                shelfEdge.resting(drawn: bars, hover: hover),
                bars
            )
        }
    }

    /// Places the bars that sit on `edge` along its `strip`.
    private func shelfPlan(
        edge shelfEdge: ShelfEdge,
        strip: CGRect,
        settings: TilingSettings,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?,
        pocket: Bool,
        drawn: Set<ShelfBar>
    ) -> ShelfPlan {
        let shelf = settings.kiwishelf
        let edge = shelfEdge.edge
        let horizontal = edge.isHorizontal
        let length = horizontal ? strip.width : strip.height
        let depth = horizontal ? strip.height : strip.width
        let look = settings.spaceBarLook
        let spaceNeed = spaceItems.map {
            SpaceBarOverlay.naturalLength(
                items: $0,
                depth: depth,
                look: look
            )
        }
        let spaceFloor =
            spaceItems.map {
                ShelfArrangement.hardFloor(
                    activeExtent: SpaceBarOverlay.activeExtent(
                        items: $0,
                        depth: depth,
                        look: look
                    ),
                    thickness: depth,
                    gap: shelf.itemGap,
                    endPads: SpaceBarOverlay.endPads(gap: shelf.itemGap)
                )
            } ?? 0
        let appNeed = app.map {
            AppBarOverlay.naturalLength(
                items: $0.items,
                style: $0.style,
                thickness: depth,
                capAxis: length
            )
        }
        return ShelfPlan(
            edge: edge,
            strip: strip,
            horizontal: horizontal,
            arrangement: ShelfArrangement.arrange(
                length: length,
                spaceNeed: spaceNeed,
                appNeed: appNeed,
                spaceFloor: spaceFloor,
                shelf: shelf,
                // A section beside a resting bar; `keeping` drops
                // it where nothing draws (#2678).
                pocket: pocket && (spaceNeed != nil || appNeed != nil)
                    ? .init(
                        need: ShelfArrangement.pocketNeed(depth: depth),
                        leadsEnd: shelf.pocketLeansEnd
                    )
                    : nil
            ),
            shelfEdge: shelfEdge,
            needs: [.space: spaceNeed, .app: appNeed].compactMapValues {
                $0
            },
            drawn: drawn,
            carriesPocket: pocket
        )
    }
}
