import AppKit

/// The pocket's section of a shelf (#2678): drawn in a panel of its
/// own beside the shelf's, so the gap between the bars' run and the
/// pocket stays click-through (#2497). Its content keeps the strip's
/// coordinates, as the shelf's does, so the shelf plays every reveal,
/// fade and glide on both contents from the same call
/// (`ShelfOverlay.motionContents`).
@MainActor
final class ShelfPocketPiece {
    /// What the shelf carries at its pocket slot: the view and its
    /// slot, AX coordinates.
    struct Mount: Equatable {
        let view: NSView
        let slot: CGRect

        static func == (a: Self, b: Self) -> Bool {
            a.view === b.view && a.slot == b.slot
        }
    }

    private(set) var panel: PocketPlatePanel?
    let root = AppBarOverlay.FlippedView()
    /// Strip-sized, offset inside the panel's room as the shelf's.
    let content = BarMenuView()
    /// What a grow fades, as the shelf's strip view.
    let items = BarMenuView()
    private(set) var mount: Mount?
    /// The view a leave still draws, until it lands.
    private(set) var leaving: NSView?
    /// The slot in strip coordinates: the panel's resting room.
    private(set) var rest: CGRect?
    /// What the panel was last asked to cover, strip coordinates.
    private(set) var placedRoom: CGRect?
    /// A press on the panel, with the view it hit and its type.
    var onPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }
    /// Orders the pocket's panel above the shelf's (#2678 review 7);
    /// a test records the pair.
    var orderAbove: @MainActor (NSWindow, NSWindow) -> Void = {
        $0.order(.above, relativeTo: $1.windowNumber)
    }
    #if DEBUG
        var ordersPanel = true
    #endif

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    var isMounted: Bool { mount != nil }
    var isVisible: Bool { panel?.isVisible == true }

    /// Takes `next` on `strip`, the view at its slot; nil empties the
    /// piece. Returns whether the mount changed.
    @discardableResult
    func take(_ next: Mount?, strip: CGRect) -> Bool {
        content.frame = CGRect(origin: content.frame.origin, size: strip.size)
        items.frame = CGRect(origin: .zero, size: strip.size)
        guard let next else {
            let had = mount != nil
            // Drawn on until its leave lands — while it is still
            // here: another shelf may have taken the view already.
            if let view = mount?.view, view.superview === items {
                leaving = view
            }
            mount = nil
            rest = nil
            return had
        }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let local = next.slot.offsetBy(dx: -strip.minX, dy: -strip.minY)
        if leaving !== next.view { dropLeaving() }
        leaving = nil
        if next.view.superview !== items {
            mount?.view.removeFromSuperview()
            items.addSubview(next.view)
            // A view joining lands at its slot; a moved slot glides
            // with the shelf (`placeView`).
            next.view.frame = local
        }
        let changed = mount != next
        mount = next
        rest = local
        return changed
    }

    /// Places the mounted view at its slot, gliding where
    /// `animated` — called inside the shelf's plate glide.
    func placeView(animated: Bool) {
        guard let view = mount?.view, let rest else { return }
        BarMotion.setFrame(view, to: rest, animated: animated)
    }

    /// Sizes the panel to `wanted` (strip coordinates, nil the rest)
    /// and offsets the content so the strip stays put on screen.
    func placeRoom(_ wanted: CGRect?, strip: CGRect) {
        guard let panel, let wanted = wanted ?? rest else { return }
        let frame = wanted.offsetBy(dx: strip.minX, dy: strip.minY).integral
        let room = frame.offsetBy(dx: -strip.minX, dy: -strip.minY)
        placedRoom = wanted
        content.frame = CGRect(
            origin: CGPoint(x: -room.minX, y: -room.minY),
            size: strip.size
        )
        let target = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        if panel.frame != target { panel.setFrame(target, display: true) }
    }

    /// Orders the panel in above `shelf`, the shelf's own panel.
    func orderIn(above shelf: NSWindow) {
        guard let panel, mount != nil else { return }
        #if DEBUG
            guard ordersPanel else { return }
        #endif
        if !panel.isVisible { panel.orderFrontRegardless() }
        orderAbove(panel, shelf)
    }

    /// Orders the panel out and drops the view a leave drew.
    func orderOut() {
        panel?.orderOut(nil)
        dropLeaving()
    }

    /// Removes the view a leave drew, only from this piece: a
    /// pocket moved to another shelf of the screen sits there now.
    private func dropLeaving() {
        if leaving?.superview === items { leaving?.removeFromSuperview() }
        leaving = nil
    }

    private func makePanel() -> PocketPlatePanel {
        let panel = BarPanel.configure(
            PocketPlatePanel(
                contentRect: .zero,
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: true
            )
        )
        panel.onPress = { [weak self] in self?.onPress($0, $1) }
        root.wantsLayer = true
        root.layer?.masksToBounds = true
        panel.contentView = root
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        root.addSubview(content)
        items.wantsLayer = true
        content.addSubview(items)
        return panel
    }
}
