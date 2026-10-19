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
        let arrangement: ShelfArrangement
        /// The edge's bars and their visibility (#761); the
        /// arrangement places only the ones drawn this pass.
        var shelfEdge: ShelfEdge
        /// Each drawn bar's natural run length, which its slot
        /// draws in (`ShelfArrangement.Slot.drawing`).
        var needs: [ShelfBar: CGFloat] = [:]

        /// Whether the edge hides to a mark (#761).
        var hides: Bool { shelfEdge.hides }
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
    /// ones a reveal shows. A plan that draws nothing still carries
    /// its strip, where a hidden bar's shortcut would show it.
    func shelfPlans(
        visible: CGRect,
        settings: TilingSettings,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?,
        drawn: (ShelfEdge) -> Set<ShelfBar>
    ) -> [ShelfPlan] {
        let folded = settings.barEdges(
            space: spaceItems != nil
                ? settings.spaceBarStyle.visibility : nil,
            app: app.flatMap { settings.appBarVisibility(in: $0.space.mode) }
        )
        let strips = ShelfGeometry.strips(
            in: visible,
            edges: folded.map(\.edge),
            shelf: settings.kiwishelf
        )
        return zip(folded, strips).map { shelfEdge, strip in
            let edge = shelfEdge.edge
            let bars = drawn(shelfEdge)
            return shelfPlan(
                edge: shelfEdge,
                strip: strip,
                settings: settings,
                spaceItems: settings.spaceBarStyle.edge == edge
                    && bars.contains(.space) ? spaceItems : nil,
                app: settings.appBarStyle.edge == edge
                    && bars.contains(.app) ? app : nil
            )
        }
    }

    /// Places the bars that sit on `edge` along its `strip`.
    private func shelfPlan(
        edge shelfEdge: ShelfEdge,
        strip: CGRect,
        settings: TilingSettings,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?
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
                shelf: shelf
            ),
            shelfEdge: shelfEdge,
            needs: [.space: spaceNeed, .app: appNeed].compactMapValues {
                $0
            }
        )
    }
}
