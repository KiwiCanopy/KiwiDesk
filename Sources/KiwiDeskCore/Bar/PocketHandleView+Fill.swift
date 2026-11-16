import AppKit

/// The tab's progress fill (#3368 amended): where the pocket's rise
/// does not play — Reduce Motion — the approach's countdown runs on
/// the tab's core as a bar handle's does, through the one
/// `BarMotion.playHandleFill`, which KiwiDesk's Off drops.
extension PocketHandleView {
    /// The turn that takes the bottom-edge layout onto `edge` in the
    /// view's own space: what `draw` concatenates and the fill's clip
    /// is placed by, so the two never part.
    func drawingTurn() -> CGAffineTransform {
        let along = edge.isHorizontal ? bounds.width : bounds.height
        let across = edge.isHorizontal ? bounds.height : bounds.width
        return CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
            .rotated(by: Self.turn(for: edge))
            .translatedBy(x: -along / 2, y: -across / 2)
    }

    /// The tab in the bottom-edge layout: flush on the edge, centred
    /// along it.
    func tabRect() -> CGRect {
        let along = edge.isHorizontal ? bounds.width : bounds.height
        let across = edge.isHorizontal ? bounds.height : bounds.width
        return CGRect(
            x: (along - Self.tabLength) / 2,
            y: across - Self.tabDepth,
            width: Self.tabLength,
            height: Self.tabDepth
        )
    }

    /// The tab's core capsule in the view's own space.
    func tabCoreFrame() -> CGRect {
        ShelfHandleSpec.parts(of: tabRect()).core.applying(drawingTurn())
            .integral(to: 0.5)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let core = tabCoreFrame()
        fillClip.frame = core
        fillClip.cornerRadius = ShelfHandleSpec.radius(of: core)
        var ink: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            ink =
                ShelfHandleSpec.fillColor(
                    hex: ShelfHandleSpec.restHex(of: shelf)
                ).cgColor
        }
        fillLayer.backgroundColor = ink
        CATransaction.commit()
        guard fillPending else { return }
        fillPending = false
        BarMotion.playHandleFill(
            fillLayer,
            in: fillClip.bounds,
            fill: fill,
            horizontal: edge.isHorizontal
        )
    }
}

extension CGRect {
    /// Rounded to the nearest `step` on every side, so a turned rect
    /// lands on the grid it was drawn on.
    fileprivate func integral(to step: CGFloat) -> CGRect {
        let round = { (value: CGFloat) in (value / step).rounded() * step }
        let x0 = round(minX)
        let y0 = round(minY)
        return CGRect(
            x: x0,
            y: y0,
            width: round(maxX) - x0,
            height: round(maxY) - y0
        )
    }
}
