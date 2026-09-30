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

        /// The strip's length along the edge.
        var length: CGFloat {
            horizontal ? strip.width : strip.height
        }

        func segment(_ slot: ShelfArrangement.Slot) -> CGRect {
            slot.rect(in: strip, horizontal: horizontal)
        }
    }

    /// Places the shown bars on the shelves of a screen whose
    /// visible frame is `visible` — the screen's, never the
    /// layout bounds, which the shelves have already left. One
    /// plan while the shown bars share an edge, one per bar while
    /// they are split (#1731), the Space Bar's first
    /// (`ShelfGeometry.strips`).
    func shelfPlans(
        visible: CGRect,
        settings: TilingSettings,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?
    ) -> [ShelfPlan] {
        let edges = settings.barEdges(
            space: spaceItems != nil,
            app: app != nil
        )
        let strips = ShelfGeometry.strips(
            in: visible,
            edges: edges,
            shelf: settings.kiwishelf
        )
        return zip(edges, strips).map { edge, strip in
            shelfPlan(
                edge: edge,
                strip: strip,
                settings: settings,
                spaceItems: settings.spaceBarStyle.edge == edge
                    ? spaceItems : nil,
                app: settings.appBarStyle.edge == edge ? app : nil
            )
        }
    }

    /// Places the bars that sit on `edge` along its `strip`.
    private func shelfPlan(
        edge: AppBarEdge,
        strip: CGRect,
        settings: TilingSettings,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?
    ) -> ShelfPlan {
        let shelf = settings.kiwishelf
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
            )
        )
    }
}
