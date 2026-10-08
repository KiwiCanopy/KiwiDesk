import AppKit

/// The peek's buttons (#1946, owner ruling): every window row picks
/// its window, and "N more" opens the menu. A press arms the button
/// under it and the release inside that button acts; dragging off
/// cancels, as a button does (#2044). The button under the pointer
/// wears the shelf's own item hover — its fill and ink — snapped,
/// as a menu row's highlight is.
extension BarPeekBody {
    enum Action: Equatable {
        case window(WindowID)
        case more
    }

    /// One button: what it does, where it takes the pointer, and
    /// the views whose ink the hover lifts, with their resting ink.
    struct Target {
        let action: Action
        let frame: CGRect
        let inks: [NSView]
        let rest: [NSColor?]
    }

    func resetTargets(_ shelf: KiwiShelf) {
        self.shelf = shelf
        targets = []
        hovered = nil
        pressed = nil
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = Metrics.hoverRadius
        highlight.isHidden = true
        highlight.setAccessibilityElement(false)
        addSubview(highlight)
    }

    /// A button around `text`, its hover reaching a little past it.
    func addTarget(_ action: Action, around text: CGRect, inks: [NSView]) {
        targets.append(
            Target(
                action: action,
                frame: text.insetBy(
                    dx: -Metrics.hoverPadH,
                    dy: -Metrics.hoverPadV
                ),
                inks: inks,
                rest: inks.map(Self.ink(of:))
            )
        )
    }

    /// The button at `point`, in the body's own coordinates.
    func target(at point: CGPoint) -> Int? {
        targets.firstIndex { $0.frame.contains(point) }
    }

    /// Lifts the button at `index`, and only it.
    func setHovered(_ index: Int?) {
        guard index != hovered else { return }
        if let old = hovered, old < targets.count {
            let target = targets[old]
            for (view, ink) in zip(target.inks, target.rest) {
                Self.paint(view, ink)
            }
        }
        hovered = index
        guard let index, index < targets.count else {
            highlight.isHidden = true
            return
        }
        let target = targets[index]
        highlight.frame = target.frame
        highlight.layer?.backgroundColor =
            NSColor(kiwiHex: shelf.hoverFillColor).cgColor
        highlight.isHidden = false
        let ink = NSColor(kiwiHex: shelf.hoverItemColor)
        target.inks.forEach { Self.paint($0, ink) }
    }

    /// A press on the button at `point` arms it.
    func press(at point: CGPoint) {
        pressed = target(at: point)
        setHovered(pressed)
    }

    /// The pointer dragged to `point` while pressed: the armed
    /// button stays lit only while the pointer is on it.
    func drag(to point: CGPoint) {
        guard let pressed else { return }
        setHovered(target(at: point) == pressed ? pressed : nil)
    }

    /// The release at `point` acts where it lands on the button the
    /// press armed; anywhere else it cancels.
    func release(at point: CGPoint) {
        defer { pressed = nil }
        guard let armed = pressed, target(at: point) == armed,
            armed < targets.count
        else { return }
        switch targets[armed].action {
        case .window(let id): onPick(id)
        case .more: onMore()
        }
    }

    private static func ink(of view: NSView) -> NSColor? {
        (view as? NSTextField)?.textColor
            ?? (view as? NSImageView)?.contentTintColor
    }

    private static func paint(_ view: NSView, _ ink: NSColor?) {
        if let field = view as? NSTextField { field.textColor = ink }
        if let image = view as? NSImageView { image.contentTintColor = ink }
    }

    // MARK: - Events

    /// The whole body takes the mouse, so its labels never swallow
    /// a press meant for the button beneath them.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        return bounds.contains(local) ? self : nil
    }

    /// A non-key panel's first click is the pick.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited, .mouseMoved, .cursorUpdate,
                    .activeAlways, .inVisibleRect,
                ],
                owner: self
            )
        )
    }

    private func local(_ event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func mouseEntered(with event: NSEvent) {
        SkyLight.ensureBackgroundCursor()
        NSCursor.arrow.set()
        setHovered(target(at: local(event)))
        onPointerInside(true)
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
        guard pressed == nil else { return }
        setHovered(target(at: local(event)))
    }

    override func mouseExited(with event: NSEvent) {
        onPointerInside(false)
        guard pressed == nil else { return }
        setHovered(nil)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        press(at: local(event))
    }

    override func mouseDragged(with event: NSEvent) {
        drag(to: local(event))
    }

    override func mouseUp(with event: NSEvent) {
        release(at: local(event))
    }
}
