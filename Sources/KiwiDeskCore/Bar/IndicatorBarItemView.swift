import AppKit

/// One entry in the indicator bar: an optional app icon and
/// name centered in the slot, a style-dependent accent
/// marking the active window, and click-to-focus. Clicks
/// never take key focus — the panel above is non-activating.
///
/// Slot layout & text measurement live in
/// IndicatorBarItemView+Layout.swift.
final class IndicatorBarItemView: NSView {
    let iconView = NSImageView()
    let label = NSTextField(labelWithString: "")
    let accent = NSView()

    private var windowID = WindowID(0)
    var name = ""
    var horizontal = true
    private(set) var isActive = false
    private var isHovered = false
    var params = MonocleParams()
    var onSelect: (WindowID) -> Void = { _ in }

    /// Flipped: content lays out top-down, so the icon sits
    /// at the visual top of vertical bars.
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        accent.wantsLayer = true
        label.alignment = .center
        addSubview(iconView)
        addSubview(label)
        addSubview(accent)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("IndicatorBarItemView is code-only")
    }

    // MARK: - Click & hover

    /// The active window's item is inert: clicking it would
    /// focus what is already focused, so it neither reacts to
    /// hover nor to clicks.
    override func mouseDown(with event: NSEvent) {
        guard !isActive else { return }
        onSelect(windowID)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [
                    .mouseEnteredAndExited, .activeAlways,
                ],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isActive else { return }
        isHovered = true
        applyColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyColors()
    }

    // MARK: - Styling

    // swiftlint:disable:next function_parameter_count
    func configure(
        id: WindowID,
        name: String,
        icon: NSImage?,
        active: Bool,
        horizontal: Bool,
        params: MonocleParams
    ) {
        windowID = id
        self.name = name
        self.horizontal = horizontal
        self.isActive = active
        self.params = params
        isHovered = false
        iconView.image = icon
        iconView.isHidden =
            params.bar.content == .name || icon == nil
        label.isHidden = params.bar.content == .icon
        applyColors()
        applyAccent()
        needsLayout = true
    }

    /// Hover swaps the box background (no overlay: a wash on
    /// top would muddy the icon and text) and the text color.
    private func applyColors() {
        label.textColor = NSColor(kiwiHex: textColorHex)
        layer?.backgroundColor =
            NSColor(kiwiHex: boxColorHex).cgColor
        // Pills round always; underline items only show their
        // box while hovered, rounded like a pill.
        let rounded =
            params.bar.style == .pills
            || (params.bar.style == .underline && isHovered)
        layer?.cornerRadius =
            rounded ? params.bar.cornerRadius : 0
    }

    private var textColorHex: String {
        if isHovered { return params.bar.hoverTextColor }
        return isActive
            ? params.bar.activeTextColor
            : params.bar.textColor
    }

    private var boxColorHex: String {
        if isHovered { return params.bar.hoverColor }
        switch params.bar.style {
        case .pills, .segments:
            return isActive
                ? params.bar.activeBoxColor
                : params.bar.boxColor
        case .underline:
            return "#00000000"
        }
    }

    /// One highlight color, three shapes: a ring around the
    /// active pill, an edge bar on the window-facing side of
    /// the active segment, the underline under the active
    /// name.
    private func applyAccent() {
        let highlighted =
            isActive && params.bar.activeStyle == .highlight
        if params.bar.style == .pills {
            layer?.borderWidth = highlighted ? 2 : 0
            layer?.borderColor =
                NSColor(
                    kiwiHex: params.bar.highlightColor
                ).cgColor
            accent.isHidden = true
            return
        }
        layer?.borderWidth = 0
        accent.isHidden = !highlighted
        accent.layer?.backgroundColor =
            NSColor(kiwiHex: params.bar.highlightColor).cgColor
    }
}
