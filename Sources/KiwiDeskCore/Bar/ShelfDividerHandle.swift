import AppKit

/// The section divider's grip (#1517, ruling 15): a strip over
/// the divider line, live only while the shelf is full. Dragging
/// it moves the Space Bar minimum; a double-click resets it. The
/// cursor is set, never pushed (gui.md).
@MainActor
final class ShelfDividerHandle: NSView {
    /// A minimum the drag reached; `committed` on the release.
    var onMinimum: (_ percent: CGFloat, _ committed: Bool) -> Void = {
        _,
        _ in
    }
    /// A double-click: restore the default minimum.
    var onReset: () -> Void = {}
    /// The pointer over the grip, or a drag holding it.
    var onHover: (Bool) -> Void = { _ in }
    private(set) var isHovered = false
    /// Set while the shelf is full; the handle hides otherwise.
    var range: ShelfArrangement.Divider?
    var horizontal = true
    /// How wide the grip reaches across the divider line.
    nonisolated static let reach: CGFloat = 8

    private var dragStart: CGPoint?
    private var dragRange: ShelfArrangement.Divider?
    /// Whether the press has moved: a click commits nothing.
    private var moved = false

    override var isFlipped: Bool { true }

    private var cursor: NSCursor {
        horizontal ? .resizeLeftRight : .resizeUpDown
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [
                    .mouseEnteredAndExited, .mouseMoved, .cursorUpdate,
                    .activeAlways, .inVisibleRect,
                ],
                owner: self
            )
        )
    }

    override func cursorUpdate(with event: NSEvent) {
        cursor.set()
    }

    /// Asked once, on the first hover: a cursor set from a panel
    /// that never activates otherwise holds only while KiwiDesk is
    /// frontmost (`SkyLight.allowBackgroundCursor`).
    private static let backgroundCursor = SkyLight.allowBackgroundCursor()

    override func mouseEntered(with event: NSEvent) {
        _ = Self.backgroundCursor
        cursor.set()
        setHovered(true)
    }

    /// Re-asserted while the pointer moves: the shelf's app is
    /// never frontmost, and the frontmost app may set its own.
    override func mouseMoved(with event: NSEvent) {
        cursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        guard dragStart == nil else { return }
        NSCursor.arrow.set()
        setHovered(false)
    }

    func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        onHover(hovered)
    }

    /// Re-reads the hover from where the pointer rests (#1665); a
    /// drag in flight keeps it, as the exit does.
    func syncHoverToPointer() {
        guard dragStart == nil else { return }
        let hovered = BarHoverHit.ownsPointer(self)
        guard hovered != isHovered else { return }
        // The cursor follows the ink, as the enter and exit set it.
        if hovered {
            _ = Self.backgroundCursor
            cursor.set()
        } else {
            NSCursor.arrow.set()
        }
        setHovered(hovered)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            dragStart = nil
            onReset()
            return
        }
        dragStart = event.locationInWindow
        dragRange = range
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        moved = true
        report(event, committed: false)
    }

    override func mouseUp(with event: NSEvent) {
        if moved { report(event, committed: true) }
        // A release off the grip gets no `mouseExited` to restore
        // the cursor.
        if !bounds.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.arrow.set()
            setHovered(false)
        }
        dragStart = nil
        dragRange = nil
        moved = false
    }

    /// The drag's travel along the shelf, measured from where it
    /// began against the range it began with — the layout moving
    /// underneath does not move the reference.
    private func report(_ event: NSEvent, committed: Bool) {
        guard let start = dragStart, let range = dragRange else { return }
        let now = event.locationInWindow
        // Window coordinates grow upward; the shelf's run grows
        // downward on a vertical edge.
        let delta = horizontal ? now.x - start.x : start.y - now.y
        guard let minimum = range.minimum(afterDragging: delta) else {
            return
        }
        onMinimum(minimum, committed)
    }
}
