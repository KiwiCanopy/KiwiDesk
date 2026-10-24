import AppKit

/// The list an anchor grows into (#2563 ▸ Ruling): the peek's
/// opening motion for the overflow mark's source, never a second
/// peek. The panel takes a room sized for the whole motion — the
/// list's resting frame, which holds the pill — and the stage
/// clips inside it, so the panel is never resized per frame and
/// the glass moves by its host.
extension BarPeekPanel {
    /// A list grown out of its anchor, shown or closing back.
    struct Morph {
        /// The overflow mark's pill; nil for a list grown out of a
        /// bar item (#2571), which hides nothing.
        weak var anchor: (any BarPeekMorphAnchor)?
        /// The bar item a list grew out of; nil for the overflow
        /// mark's.
        weak var item: NSView?
        let edge: AppBarEdge
        /// When it opened, for the double-click guard (#2063).
        let openedAt: TimeInterval
    }

    /// What a grown list is shown from: its anchor, the pill's
    /// frame on screen and the run end's edge.
    struct MorphRequest {
        let anchor: any BarPeekMorphAnchor
        let pill: CGRect
        let edge: AppBarEdge
    }

    /// Shows `content` grown out of `request`'s pill, inside the
    /// anchor's room and the usable area `visible`; a list already
    /// shown is redrawn in place.
    func showMorph(
        _ content: BarPeekContent,
        shelf stored: KiwiShelf,
        request: MorphRequest,
        visible: CGRect
    ) {
        let shelf = LiquidGlassGate.rendered(stored)
        // A bar item's list in its place ends at once (#2571).
        if morph?.item != nil { dropMorph() }
        let room = request.anchor.morphRoom.intersection(visible)
        let area = room.isNull ? visible : room
        let atTop = BarPeekMorph.headerAtTop(request.edge)
        let depth = BarPeekMorph.headerDepth
        body.reserve = BarPeekBody.Reserve(
            top: atTop ? depth : 0,
            bottom: atTop ? 0 : depth,
            minWidth: request.pill.width
        )
        let size = body.build(
            content,
            shelf: shelf,
            maxHeight: BarPeekMorph.maxHeight(
                pill: request.pill,
                edge: request.edge,
                room: area
            ),
            cutAtTop: !atTop
        )
        let list = BarPeekMorph.listFrame(
            size: size,
            pill: request.pill,
            edge: request.edge,
            room: area
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.takesKey = true
        panel.setFrame(list, display: false)
        paint(shelf, edge: request.edge, size: list.size)
        let strip = BarPeekMorph.header(in: list.size, edge: request.edge)
        header.frame = strip
        header.isHidden = false
        let count = BarPeekMorph.count(
            width: request.pill.width,
            pill: request.pill,
            list: list,
            edge: request.edge
        )
        header.render(
            text: request.anchor.morphText,
            shelf: shelf,
            count: CGRect(
                x: count.minX,
                y: 0,
                width: count.width,
                height: strip.height
            )
        )
        let opens = morph == nil || leaving != nil || !panel.isVisible
        leaving = nil
        drawn = content
        panel.ignoresMouseEvents = false
        morph = Morph(
            anchor: request.anchor,
            edge: request.edge,
            openedAt: opens ? now() : morph?.openedAt ?? now()
        )
        guard opens else {
            panel.invalidateShadow()
            return
        }
        // The pill hides in the same pass the list orders in.
        request.anchor.setMorphed(true, pointer: pointer())
        panel.hasShadow = false
        panel.orderFrontRegardless()
        guard let parts = morphParts() else { return }
        let span = BarMotion.playMorph(
            parts,
            panel: panel,
            anchor: request.anchor.window,
            pill: local(request.pill, in: list),
            pillRadius: min(request.pill.width, request.pill.height) / 2,
            listRadius: BarPeekBody.Metrics.cornerRadius,
            opening: true
        )
        let token = UUID()
        opening = token
        land(span) { [weak self] in
            guard let self, self.opening == token else { return }
            self.opening = nil
            BarMotion.endMorph(parts)
            self.panel?.hasShadow = true
            self.panel?.invalidateShadow()
        }
    }

    /// Shrinks the list back into its anchor's current frame and
    /// brings the pill back as it lands; where no pill is left in
    /// the room — the count ran out, the window moved — it fades.
    func closeMorph() {
        guard let morph, let panel, leaving == nil else { return }
        drawn = nil
        opening = nil
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        let token = UUID()
        leaving = token
        let land: @MainActor () -> Void = { [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.panel?.orderOut(nil)
            self.endMorph()
            morph.anchor?.setMorphed(false, pointer: pointer())
        }
        guard let target = closingTarget(morph, list: panel.frame),
            panel.frame.insetBy(dx: -1, dy: -1).contains(target),
            let parts = morphParts()
        else {
            BarMotion.fadePeek(panel, to: 0, animated: true, landed: land)
            return
        }
        let span = BarMotion.playMorph(
            parts,
            panel: panel,
            anchor: morph.anchor?.window,
            pill: local(target, in: panel.frame),
            pillRadius: min(target.width, target.height) / 2,
            listRadius: BarPeekBody.Metrics.cornerRadius,
            opening: false,
            fadesOut: morph.item != nil
        )
        self.land(span, land)
    }

    /// Ends a grown list at once — another peek shows in its place.
    func dropMorph() {
        guard let morph else { return }
        leaving = nil
        // Clearing `takesKey` resigns nothing: the peek showing next
        // must not keep the keyboard the list took.
        if panel?.isKeyWindow == true { panel?.orderOut(nil) }
        endMorph()
        morph.anchor?.setMorphed(false, pointer: pointer())
    }

    /// Where a closing list shrinks to on screen: the pill's current
    /// frame, or the seed off the item's (#2571); nil where neither
    /// is on screen.
    private func closingTarget(_ morph: Morph, list: CGRect) -> CGRect? {
        if let anchor = morph.anchor {
            return BarPeek.screenFrame(of: anchor)
        }
        guard let item = morph.item,
            let frame = BarPeek.screenFrame(of: item)
        else { return nil }
        return BarPeekMorph.seed(item: frame, list: list, edge: morph.edge)
    }

    /// Whether a press on a held list's header or item closes it:
    /// never the second press of the double-click that opened it
    /// (#2063).
    func pressCloses(_ clickCount: Int) -> Bool {
        guard let morph else { return true }
        return BarPeekMorph.headerCloses(
            clickCount: clickCount,
            sinceOpen: now() - morph.openedAt,
            doubleClick: NSEvent.doubleClickInterval
        )
    }

    /// A press on the header strip closes the list, save the second
    /// press of the double-click that opened it (#2063).
    func headerPressed(_ clickCount: Int) {
        guard morph != nil, drawn != nil, pressCloses(clickCount)
        else { return }
        onClose()
    }

    /// A key on the grown list: Escape closes it, the arrows walk
    /// its rows, Return picks the lifted one; any other closes it.
    func morphKey(_ code: UInt16) -> Bool {
        guard morph != nil else { return false }
        // Closing, the panel still holds the keyboard until it lands:
        // a key then is swallowed, never a beep.
        guard drawn != nil else { return true }
        switch code {
        case 53: onClose()
        case 125: body.stepHover(by: 1)
        case 126: body.stepHover(by: -1)
        case 36, 76: body.activateHovered()
        // Any other key closes the list rather than vanishing into a
        // beep: the user is typing for the app beneath.
        default: onClose()
        }
        return true
    }

    private func endMorph() {
        if let parts = morphParts() { BarMotion.endMorph(parts) }
        morph = nil
        opening = nil
        header.isHidden = true
        panel?.takesKey = false
        panel?.hasShadow = true
        panel?.alphaValue = 1
    }

    func morphParts() -> BarPeekMorphParts? {
        guard let stage = stage.layer, let rows = body.layer,
            let markInk = header.markInk.layer,
            let listInk = header.listInk.layer
        else { return nil }
        return BarPeekMorphParts(
            stage: stage,
            rows: rows,
            markInk: markInk,
            listInk: listInk
        )
    }

    /// `rect` on screen in the coordinates of a panel framed
    /// `panel`.
    func local(_ rect: CGRect, in panel: CGRect) -> CGRect {
        rect.offsetBy(dx: -panel.minX, dy: -panel.minY)
    }
}
