import AppKit

/// A grown list's header (#2563 ▸ Ruling): the pill's count kept
/// where the pill sat, crossing from the mark's ink to the list's,
/// and the whole strip the list's close target.
@MainActor
final class BarPeekHeader: NSView {
    /// A press on the strip, with its click count.
    var onPress: @MainActor (Int) -> Void = { _ in }
    /// The count in the mark's ink, which fades out as the list
    /// grows, and in the list's, which fades in.
    let markInk = NSTextField(labelWithString: "")
    let listInk = NSTextField(labelWithString: "")

    /// Flipped as the mark is, so the count's ink sits where the
    /// pill drew it.
    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
        for label in [markInk, listInk] {
            label.alignment = .center
            label.isBezeled = false
            label.drawsBackground = false
            label.wantsLayer = true
            label.setAccessibilityElement(false)
            addSubview(label)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Draws `text` in the overflow mark's face, its count framed
    /// `count` in the strip's own coordinates.
    func render(text: String, shelf: KiwiShelf, count: CGRect) {
        let font = shelf.badgeFont(
            ofSize: OverflowMarkView.textSize,
            emphasis: .semibold
        )
        markInk.textColor = NSColor(kiwiHex: shelf.itemColor)
        listInk.textColor = NSColor(kiwiHex: shelf.peekHeaderColor)
        for label in [markInk, listInk] {
            label.stringValue = text
            label.font = font
            label.sizeToFit()
            label.frame = CGRect(
                x: count.minX,
                y: BarTextGlyph.originY(
                    centredOn: count.midY,
                    for: label,
                    band: .figures,
                    height: label.frame.height
                ),
                width: count.width,
                height: label.frame.height
            )
        }
        markInk.layer?.opacity = 0
        listInk.layer?.opacity = 1
    }

    /// The whole strip takes the press, its labels none.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden else { return nil }
        let local = superview.map { convert(point, from: $0) } ?? point
        return bounds.contains(local) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onPress(event.clickCount)
    }
}
