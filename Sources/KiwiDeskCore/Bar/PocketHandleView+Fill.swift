import AppKit

/// The tab's progress fill (#3368 amended): where the pocket's rise
/// does not play — Reduce Motion — the approach's countdown runs on
/// the tab's core as a bar handle's does, through the one
/// `BarMotion.playHandleFill`, which KiwiDesk's Off drops.
extension PocketHandleView {
    /// The tab's core capsule in the view's own space, turned with
    /// its edge as the drawing is.
    func tabCoreFrame() -> CGRect {
        let along = edge.isHorizontal ? bounds.width : bounds.height
        let across = edge.isHorizontal ? bounds.height : bounds.width
        let tab = CGRect(
            x: (along - Self.tabLength) / 2,
            y: across - Self.tabDepth,
            width: Self.tabLength,
            height: Self.tabDepth
        )
        let turn = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
            .rotated(by: Self.turn(for: edge))
            .translatedBy(x: -along / 2, y: -across / 2)
        return ShelfHandleSpec.parts(of: tab).core.applying(turn)
            .integral(to: 0.5)
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
