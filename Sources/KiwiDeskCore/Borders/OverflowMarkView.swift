import AppKit

/// The overflow mark's drawing (#2235): KiwiShelf's look — its
/// Fill as tinted glass or solid, its rim, its item ink and bar
/// face — around the "+n" count, a pill or a circle. A button to
/// VoiceOver; the pointer reports to the shared hover peek.
@MainActor
final class OverflowMarkView: NSView {
    /// The count's fixed reading size, the peek's header size.
    static let textSize: CGFloat = 11

    /// The pointer entered (true) or left (false) the mark.
    var onHover: @MainActor (Bool) -> Void = { _ in }
    /// A left click on the mark.
    var onClick: @MainActor () -> Void = {}
    /// VoiceOver's press.
    var onPress: @MainActor () -> Void = {}

    let label = NSTextField(labelWithString: "")
    private let content = NSView()
    private let solid = NSView()
    private let tint = GlassBackdrop()
    private let rim = ShelfBorder.make()
    private var glass: NSView?
    private var tracking: NSTrackingArea?
    /// The gated shelf the mark draws in — the peek wears it.
    private(set) var shelfLook = KiwiShelf()
    private(set) var hovered = false

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        solid.wantsLayer = true
        solid.layer?.masksToBounds = true
        content.wantsLayer = true
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.setAccessibilityElement(false)
        content.addSubview(label)
        addSubview(solid)
        addSubview(content)
        addSubview(rim)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The width the count `text` takes in `shelf`'s badge face.
    static func textWidth(_ text: String, shelf: KiwiShelf) -> CGFloat {
        let font = shelf.badgeFont(ofSize: textSize, emphasis: .semibold)
        return ceil(
            (text as NSString).size(withAttributes: [.font: font]).width
        )
    }

    /// Draws `text` in the gated `shelf` (glass already stood down
    /// under Reduce transparency), named `name` to VoiceOver.
    func render(text: String, name: String, shelf gated: KiwiShelf) {
        shelfLook = gated
        label.stringValue = text
        label.font = gated.badgeFont(
            ofSize: Self.textSize,
            emphasis: .semibold
        )
        label.textColor = NSColor(kiwiHex: gated.itemColor)
        setAccessibilityLabel(name)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let radius = min(bounds.width, bounds.height) / 2
        content.frame = bounds
        label.sizeToFit()
        let width = max(label.frame.width, bounds.width)
        label.frame = CGRect(
            x: (bounds.width - width) / 2,
            y: BarTextGlyph.originY(
                centredOn: bounds.midY,
                for: label,
                band: .figures,
                height: label.frame.height
            ),
            width: width,
            height: label.frame.height
        )
        paintPlate(radius: radius)
        rim.frame = bounds
        // The shelf rims whichever surface it draws, so the mark
        // takes its border whenever the border is on.
        ShelfBorder.paint(
            rim,
            shelf: shelfLook,
            surface: shelfLook.drawsPlate ? .plate : .box,
            under: nil,
            cornerRadius: radius,
            sheen: 0
        )
    }

    private func paintPlate(radius: CGFloat) {
        if shelfLook.glassEnabled, let glass = glassView() {
            solid.isHidden = true
            glass.isHidden = false
            GlassPlate.setContent(glass, content)
            GlassPlate.update(glass, frame: bounds, cornerRadius: radius)
            GlassTint.apply(
                tint,
                below: glass,
                frame: bounds,
                cornerRadius: radius,
                hex: shelfLook.fillColor,
                edge: .top
            )
            return
        }
        if let glass, GlassPlate.holds(glass, content) {
            GlassPlate.release(glass)
        }
        glass?.isHidden = true
        tint.isHidden = true
        solid.isHidden = false
        solid.frame = bounds
        solid.layer?.cornerRadius = radius
        solid.layer?.backgroundColor =
            NSColor(kiwiHex: shelfLook.fillColor).cgColor
        if content.superview !== self {
            addSubview(content, positioned: .above, relativeTo: solid)
        }
        content.frame = bounds
    }

    /// The glass, made once beneath the count; nil below 26.
    private func glassView() -> NSView? {
        if let glass { return glass }
        guard let made = GlassPlate.make() else { return nil }
        addSubview(made, positioned: .above, relativeTo: solid)
        glass = made
        return made
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        onHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        onHover(false)
    }

    /// The whole mark is one target: the count and the plate
    /// beneath it never take a press of their own.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
