import AppKit

/// The overflow mark's panel (#2235): a press on it reaches
/// `onPress` before the view takes it, read through
/// `ShelfPanel.pressType` as on the shelf's panel — save the
/// mark's own left press, whose click opens its list.
final class OverflowMarkPanel: NSPanel {
    var onPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }

    override func sendEvent(_ event: NSEvent) {
        let hit = contentView?.hitTest(event.locationInWindow)
        if let type = ShelfPanel.pressType(of: event),
            Self.closesPeek(hit: hit, type: type)
        {
            onPress(hit, type)
        }
        super.sendEvent(event)
    }

    /// Whether a press closes the peek: every press but a left
    /// one on the mark, which opens it.
    static func closesPeek(hit: NSView?, type: NSEvent.EventType) -> Bool {
        type != .leftMouseDown || !(hit is OverflowMarkView)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// One overflow mark on screen (#2235): its panel rides its anchor
/// window, ordered just above it like the sticky mark, and stays on
/// that window's Desktop unless the window is carried.
@MainActor
final class OverflowMarkOverlay {
    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    let view = OverflowMarkView()
    /// A press on the panel, ahead of the view (`OverflowMarkPanel`).
    var onPanelPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }
    private(set) var panel: OverflowMarkPanel?
    private(set) var mark: OverflowMark
    private var size = CGSize(
        width: OverflowMark.depth,
        height: OverflowMark.depth
    )
    /// The anchor's frame last placed against, AX coordinates.
    private(set) var lastFrame: CGRect?
    private var hasOrdered = false
    private var spans = false
    #if DEBUG
        /// Whether the panel orders in; off in both `makeTestCore`
        /// twins, so no Stack fixture puts a window on screen.
        var ordersPanel = true
    #endif
    private var mayOrder: Bool {
        #if DEBUG
            return ordersPanel
        #else
            return true
        #endif
    }
    /// Whether a sync owes this mark a stack.
    var needsOrder: Bool { !hasOrdered }

    init(mark: OverflowMark) {
        self.mark = mark
    }

    /// Takes `mark`'s count and bounds, drawn in `shelf`.
    func set(_ mark: OverflowMark, name: String, shelf: KiwiShelf) {
        // A scroll step moves the end to another window: the held
        // frame was the old anchor's, and the mark owes a stack
        // above the new one.
        if mark.anchor != self.mark.anchor {
            lastFrame = nil
            hasOrdered = false
        }
        self.mark = mark
        let text = "+\(mark.count)"
        size = OverflowMark.size(
            end: mark.end,
            textWidth: OverflowMarkView.textWidth(text, shelf: shelf)
        )
        view.render(text: text, name: name, shelf: shelf)
    }

    /// Joins every Desktop only while its anchor is carried (#2149's
    /// rule for the ring); leaving that re-homes the panel.
    func setSpans(_ on: Bool) {
        guard on != spans else { return }
        spans = on
        guard let panel else { return }
        if on {
            panel.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            panel.collectionBehavior.remove(.canJoinAllSpaces)
            if panel.isVisible { panel.orderOut(nil) }
            hasOrdered = false
        }
    }

    /// Places the mark on the anchor framed `frame` (AX).
    func update(frame: CGRect) {
        lastFrame = frame
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let rect = OverflowMark.frame(
            end: mark.end,
            size: size,
            anchor: frame,
            bounds: mark.bounds
        )
        let flipped = GeometryUtils.flip(
            rect,
            primaryHeight: GeometryUtils.primaryHeight
        )
        if panel.frame != flipped {
            panel.setFrame(flipped, display: false)
        }
        view.frame = CGRect(origin: .zero, size: flipped.size)
        if !panel.isVisible, mayOrder {
            panel.orderFrontRegardless()
            hasOrdered = false
        }
    }

    /// Owes the mark a stack at the next sync.
    func oweOrder() { hasOrdered = false }

    /// Stacks the mark above its anchor window.
    func order() {
        guard let panel, mayOrder else { return }
        panel.order(.above, relativeTo: Int(mark.anchor.raw))
        hasOrdered = true
    }

    func hide() {
        panel?.orderOut(nil)
        hasOrdered = false
    }

    private func makePanel() -> OverflowMarkPanel {
        let panel = OverflowMarkPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // A fixed shadow keeps a light Fill apart from a white title
        // bar; it is geometry, never a palette key.
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.hidesOnDeactivate = false
        // `.transient` hides it in Mission Control, as the ring; no
        // `.canJoinAllSpaces` unless carried, so it leaves with its
        // window's Desktop.
        panel.collectionBehavior = [
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        if spans { panel.collectionBehavior.insert(.canJoinAllSpaces) }
        panel.onPress = { [weak self] hit, type in
            self?.onPanelPress(hit, type)
        }
        panel.contentView = view
        return panel
    }
}
