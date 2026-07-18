import AppKit

/// One Space in the Space Bar (#293): the space's identifier
/// glyph followed by a compact row (horizontal bar) or column
/// (vertical bar) of app glyphs for the windows currently in
/// that space. Click focuses the space; app glyphs are
/// informational in v1 — never nested click targets.
///
/// Two-accent rendering: inactive spaces draw everything in
/// `textColor`; the active space draws identifier + glyphs in
/// `activeTextColor`, and the focused window's glyph in
/// `focusedItemColor`. Emoji identifiers and native app images
/// stay untinted — shape (the active indicator) carries the
/// active state there.
final class SpaceBarItemView: NSView {
    /// The space identifier, resolved by the driver.
    enum Identifier: Equatable {
        /// A template SF Symbol, tinted by space state.
        case symbol(String)
        /// Emoji or single character; emoji render untinted.
        case text(String, tinted: Bool)
    }

    /// One app glyph in the space's row.
    struct App: Equatable {
        let name: String
        let icon: NSImage?
        /// App Font ligature; non-nil replaces `icon` and
        /// follows the text-color ladder (#294).
        let glyph: String?
        let focused: Bool
    }

    let identifierImage = NSImageView()
    let identifierLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    var appViews: [NSView] = []
    let accent = NSView()

    private(set) var space = SpaceID("1")
    private(set) var spaceGlyph = Identifier.text(
        "?",
        tinted: true
    )
    private(set) var apps: [App] = []
    private(set) var isActive = false
    private var isHovered = false
    var horizontal = true
    var style = SpaceBarStyle()
    var onSelect: (SpaceID) -> Void = { _ in }

    /// Flipped so the identifier leads at the visual top on
    /// vertical bars and glyphs read in flat-array order (same
    /// convention as `AppBarOverlay.FlippedView`).
    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        accent.wantsLayer = true
        addSubview(identifierImage)
        addSubview(identifierLabel)
        addSubview(accent)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        guard !isActive else { return }
        onSelect(space)
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
        restyle()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        restyle()
    }

    // MARK: - Configuration

    func configure(
        space: SpaceID,
        spaceGlyph: Identifier,
        apps: [App],
        active: Bool,
        horizontal: Bool,
        style: SpaceBarStyle
    ) {
        self.space = space
        self.spaceGlyph = spaceGlyph
        self.apps = apps
        self.isActive = active
        self.horizontal = horizontal
        self.style = style
        // Hover is NOT reset here: a retile under the pointer
        // (focus changes are frequent) must not drop the tint —
        // mouseExited still fires when the pointer leaves.
        syncAppViews()
        restyle()
        needsLayout = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(axLabel)
    }

    private var axLabel: String {
        let name = L(
            "space_bar.item.ax.space",
            "Space %1$@, %2$d applications",
            space.raw,
            apps.count
        )
        return isActive
            ? L(
                "space_bar.item.ax.current",
                "%1$@, current",
                name
            )
            : L(
                "space_bar.item.ax.not_current",
                "%1$@, not current",
                name
            )
    }

    /// One subview per app: a text field for App Font glyphs, an
    /// image view otherwise. Recreating (not pooling) is
    /// load-bearing: `styleApps` never re-sets an image view's
    /// `image`, so naive reuse would show stale icons.
    private func syncAppViews() {
        appViews.forEach { $0.removeFromSuperview() }
        appViews = apps.map { app in
            if app.glyph != nil {
                let tf = NSTextField(labelWithString: "")
                tf.alignment = .center
                tf.setAccessibilityElement(false)
                addSubview(tf)
                return tf
            }
            let iv = NSImageView()
            iv.image = app.icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.setAccessibilityElement(false)
            addSubview(iv)
            return iv
        }
    }

    // MARK: - Styling

    func restyle() {
        layer?.masksToBounds = true
        layer?.cornerRadius =
            style.tabBackground == .boxed ? cornerRadius : 0
        layer?.backgroundColor = boxColor.cgColor
        styleIdentifier()
        styleApps()
        styleAccent()
    }

    var cornerRadius: CGFloat {
        style.resolvedCornerRadius(
            forThickness: min(bounds.width, bounds.height)
        )
    }

    private var boxColor: NSColor {
        // Active wins over hover (matching `stateColor` and the
        // mouseEntered guard): a click that activates the item
        // under the pointer must not leave it hover-tinted.
        if isActive, style.tabBackground == .boxed {
            return NSColor(kiwiHex: style.activeBoxColor)
        }
        if isActive { return .clear }
        if isHovered {
            return NSColor(kiwiHex: style.hoverColor)
        }
        guard style.tabBackground == .boxed else {
            return .clear
        }
        return NSColor(kiwiHex: style.boxColor)
    }

    /// The state tier a tinted element takes: active space
    /// accent, hover text, or the inactive tier.
    private var stateColor: NSColor {
        if isActive {
            return NSColor(kiwiHex: style.activeTextColor)
        }
        if isHovered {
            return NSColor(kiwiHex: style.hoverTextColor)
        }
        return NSColor(kiwiHex: style.textColor)
    }

    private func styleIdentifier() {
        switch spaceGlyph {
        case .symbol(let name):
            identifierLabel.isHidden = true
            identifierImage.isHidden = false
            identifierImage.image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: nil
            )
            identifierImage.symbolConfiguration =
                NSImage.SymbolConfiguration(
                    pointSize: identifierFont,
                    weight: .regular
                )
            identifierImage.contentTintColor = stateColor
        case .text(let text, let tinted):
            identifierImage.isHidden = true
            identifierLabel.isHidden = false
            identifierLabel.stringValue = text
            identifierLabel.textColor =
                tinted ? stateColor : .labelColor
        }
    }

    private func styleApps() {
        for (index, app) in apps.enumerated() {
            guard index < appViews.count else { break }
            if let glyphField = appViews[index] as? NSTextField {
                glyphField.stringValue = app.glyph ?? ""
                glyphField.font =
                    AppFont.font(size: glyphSize)
                    ?? .systemFont(ofSize: glyphSize)
                glyphField.textColor =
                    app.focused && isActive
                    ? NSColor(kiwiHex: style.focusedItemColor)
                    : stateColor
            }
        }
    }

    private func styleAccent() {
        accent.isHidden = !isActive
        guard isActive else { return }
        let highlight = NSColor(kiwiHex: style.highlightColor)
        switch style.activeIndicator {
        case .ring:
            accent.layer?.backgroundColor = nil
            accent.layer?.borderColor = highlight.cgColor
            accent.layer?.borderWidth = 2
            accent.layer?.cornerRadius =
                style.tabBackground == .boxed ? cornerRadius : 0
        case .edgeMark:
            accent.layer?.borderWidth = 0
            accent.layer?.cornerRadius = 0
            accent.layer?.backgroundColor = highlight.cgColor
        case .gap:
            // No shape marker: `gap` hides the App Bar's active
            // item, which cannot apply to a space identifier —
            // colors alone carry the state.
            accent.isHidden = true
        }
    }

    var identifierFont: CGFloat {
        let thickness =
            horizontal
            ? bounds.height : bounds.width
        let base =
            style.fontSize > 0
            ? style.fontSize : thickness * 0.5
        return min(base, max(thickness - 8, 8))
    }

    var glyphSize: CGFloat {
        identifierFont * 0.9
    }

    // Layout lives in SpaceBarItemView+Layout.swift.
}
