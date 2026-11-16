import AppKit

/// The view a handle draws (#761, #3349, #3360, #3361), and
/// VoiceOver's way to the show/hide action: its press runs the
/// action and its value says whether the shelf is shown. A 2 pt
/// core between two opposite-tone hairlines; only the core runs an
/// approach's fill.
final class ShelfHandleView: NSView {
    private(set) var spec: ShelfHandleSpec?
    /// The bar the action names, for the label.
    var carriesSpaceBar = true
    var onPress: @MainActor () -> Void = {}

    /// Holds the core and the hairlines; it fades out under a shelf
    /// revealing over it and back as it retracts, the view itself
    /// staying for VoiceOver.
    let body = AppBarOverlay.FlippedView()
    let core = NSView()
    private let hairlines = (NSView(), NSView())
    /// The fill's layer, inside the core.
    let fillLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        body.wantsLayer = true
        for view in [core, hairlines.0, hairlines.1] {
            view.wantsLayer = true
            body.addSubview(view)
        }
        core.layer?.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    /// Draws `spec` in the current bounds, the handle's own frame,
    /// running or dropping its fill (`BarMotion.playHandleFill`).
    func render(_ spec: ShelfHandleSpec, animated: Bool) {
        let was = self.spec
        self.spec = spec
        body.frame = bounds
        let parts = ShelfHandleSpec.parts(of: bounds, edge: spec.edge)
        core.frame = parts.core
        hairlines.0.frame = parts.hairlines.0
        hairlines.1.frame = parts.hairlines.1
        paint(spec)
        if was?.fill != spec.fill || was?.frame != spec.frame {
            BarMotion.playHandleFill(
                fillLayer,
                in: core.bounds,
                fill: spec.fill,
                horizontal: spec.horizontal
            )
        }
        // The handle gives way to the shelf it reveals and comes
        // back as the shelf's retract lands.
        if let was, was.standsAside != spec.standsAside, animated {
            BarMotion.fadeMark(
                body,
                showing: !spec.standsAside,
                reveal: spec.reveal
            )
        } else if was?.standsAside != spec.standsAside || !animated {
            body.alphaValue = spec.standsAside ? 0 : 1
        }
    }

    /// Never the bar's own ink, which vanishes on a light window
    /// (#3349, #3357): the core's ink at rest, its fill at the fill
    /// strength, a neutral hairline either side (#3361).
    private func paint(_ spec: ShelfHandleSpec) {
        var rest: CGColor?
        var filled: CGColor?
        var hairline: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            rest = ShelfHandleSpec.restColor(hex: spec.restHex).cgColor
            filled = ShelfHandleSpec.fillColor(hex: spec.restHex).cgColor
            hairline =
                ShelfHandleSpec.hairlineColor(hex: spec.restHex).cgColor
        }
        core.layer?.backgroundColor = rest
        hairlines.0.layer?.backgroundColor = hairline
        hairlines.1.layer?.backgroundColor = hairline
        fillLayer.backgroundColor = filled
    }

    /// The inks follow the appearance; a running fill runs on.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if let spec { paint(spec) }
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override func accessibilityLabel() -> String? {
        carriesSpaceBar
            ? L("kiwishelf.indicator.space_bar.ax", "Space Bar")
            : L("kiwishelf.indicator.app_bar.ax", "App Bar")
    }

    override func accessibilityValue() -> Any? {
        let shown = spec?.shown == true
        guard let place = spec?.position else {
            return shown
                ? L("kiwishelf.indicator.shown.ax", "Shown")
                : L("kiwishelf.indicator.hidden.ax", "Hidden")
        }
        return shown
            ? L(
                "kiwishelf.indicator.shown_position.ax",
                "Shown, Space %1$d of %2$d",
                place.index,
                place.count
            )
            : L(
                "kiwishelf.indicator.hidden_position.ax",
                "Hidden, Space %1$d of %2$d",
                place.index,
                place.count
            )
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
