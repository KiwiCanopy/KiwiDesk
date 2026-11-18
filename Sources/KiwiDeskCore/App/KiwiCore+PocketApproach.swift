import AppKit

/// The pocket's resting handle joins the revealer's approach
/// (#3368 ruling 3): lingering near the tab rises the pocket as its
/// countdown, a rest on the tab hurries it, a push on a free edge
/// stands it at once, and on an edge macOS owns the outermost row
/// hands the approach to macOS, as a bar's does (#3349 rule 5).
extension KiwiCore {
    /// The revealer's key for the pocket handle on `display`.
    func pocketApproachKey(on display: DisplayID) -> ShelfRevealer.Key {
        .pocket(
            on: ShelfManager.Key(
                display: display,
                edge: shelf(on: display).pocketEdge
            )
        )
    }

    /// Files each display's resting pocket handle with the revealer:
    /// an approach `ShelfReveal.approachReach` deep across the
    /// handle's band, its tab the hover band, the risen pocket the
    /// section that holds it shown. Run after the bar pass filed
    /// `markBands`, which places the handle.
    func filePocketApproaches(into hiding: inout HidingShelves) {
        guard pocketStands else { return }
        let primary = GeometryUtils.primaryHeight
        let flip = { GeometryUtils.flip($0, primaryHeight: primary) }
        let screens = ScreenList.all.map(\.frame)
        for display in state.workspaces.allDisplays {
            guard pocketStands(on: display.id),
                pocketPlace(on: display.id) == .handle,
                // The empty depth: only a bar pass files this, and an
                // emptying verb runs none, so the held kiwis' extra
                // reach is drawn, never approached (#3446).
                let rest = pocketHandleFrame(
                    on: display.id,
                    risen: false,
                    holds: false
                ),
                let risen = pocketHandleFrame(on: display.id, risen: true),
                let screen = TilingEngine.screen(for: display.id)
            else { continue }
            let tab = flip(rest)
            let edge = shelf(on: display.id).pocketEdge
            hiding.targets[pocketApproachKey(on: display.id)] = .along(
                tab,
                edge: edge,
                side: Self.screenSide(of: tab, edge: edge),
                screen: screen.frame,
                beyond: HidingShelves.continues(
                    edge,
                    of: screen.frame,
                    along: tab,
                    among: screens
                ),
                handle: tab,
                section: flip(risen),
                // Across the band alone, never past its ends.
                cut: (lead: true, trail: true)
            )
        }
    }

    /// The side of `rect` on `edge`, Cocoa: where the handle meets
    /// the usable area's edge.
    static func screenSide(of rect: CGRect, edge: AppBarEdge) -> CGFloat {
        switch edge {
        case .top: rect.maxY
        case .bottom: rect.minY
        case .left: rect.minX
        case .right: rect.maxX
        }
    }

    /// Whether the pointer is on `display`'s tab: its approach's hover
    /// band, as the revealer last filed it — a pass behind where the
    /// tab moves, which a rise never outlasts.
    func pocketPointerOnTab(on display: DisplayID) -> Bool {
        let reveal = shelves.reveal
        guard let tab = reveal.targets[pocketApproachKey(on: display)]?.handle
        else { return false }
        return tab.contains(reveal.location())
    }

    /// Redraws the rising pockets whose tab the pointer crossed onto
    /// or off since the last move, which no fill change marks.
    func relightPocketTabs() {
        let on = Set(
            pocketPlate.specs.values.filter { $0.rise != nil }.map(\.display)
                .filter { pocketPointerOnTab(on: $0) }
        )
        guard on != pocketPlate.pointerOnTab else { return }
        pocketPlate.pointerOnTab = on
        updatePocketPlate()
    }

    /// Where the pocket on `display` stands in its approach: risen
    /// once the approach opened it, else its countdown — the scrubbed
    /// rise where the bars' motion plays, else the tab's progress
    /// fill, which Reduce Motion keeps and which steps to full under
    /// Off or the Reveal off (#3471).
    func pocketApproach(
        on display: DisplayID
    ) -> (
        open: Bool, rise: ShelfHandleSpec.Fill?, tabFill: ShelfHandleSpec.Fill?
    ) {
        let key = pocketApproachKey(on: display)
        let open = shelves.reveal.reveal(of: key).isShown
        let fill = open ? nil : shelves.reveal.fills[key]
        let scrubs = BarMotion.pocketScrubs
        return (open, scrubs ? fill : nil, scrubs ? nil : fill)
    }
}
