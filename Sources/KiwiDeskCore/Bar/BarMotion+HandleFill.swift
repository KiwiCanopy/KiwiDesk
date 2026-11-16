import AppKit

/// An approach's fill along a handle's core (#3360): it runs out
/// from the point nearest the pointer to both ends, which reach
/// the core's ends together as the bar opens. It is a change of
/// lightness in place, so it plays under Reduce Motion as the
/// reveal does (ruling 5); KiwiDesk's Off drops it with the reveal
/// (#3238), read through `revealLength`.
extension BarMotion {
    /// The fill's start in `bounds`, a layer's unflipped space: no
    /// length, at `origin`'s share of the core from its leading end
    /// — the left, or on a side edge the top, as AX reads the run.
    static func handleFillStart(
        origin: CGFloat,
        in bounds: CGRect,
        horizontal: Bool
    ) -> CGRect {
        let share = min(max(origin, 0), 1)
        return horizontal
            ? CGRect(
                x: bounds.minX + share * bounds.width,
                y: bounds.minY,
                width: 0,
                height: bounds.height
            )
            : CGRect(
                x: bounds.minX,
                y: bounds.maxY - share * bounds.height,
                width: bounds.width,
                height: 0
            )
    }

    /// The key the fill's animation runs under.
    static let handleFillKey = "handleFill"

    /// Runs `fill` on `layer` inside `bounds`, from where a running
    /// fill stands — a rest on the handle hurries it on (ruling 2) —
    /// to the whole core over its `length`; nil drops it, and so
    /// does a reveal length of 0.
    @MainActor static func playHandleFill(
        _ layer: CALayer,
        in bounds: CGRect,
        fill: ShelfHandleSpec.Fill?,
        horizontal: Bool
    ) {
        let running = layer.animation(forKey: handleFillKey) != nil
        let from = running ? layer.presentation()?.frame : nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        layer.removeAnimation(forKey: handleFillKey)
        guard let fill, revealLength > 0 else {
            layer.isHidden = true
            layer.frame = bounds
            return
        }
        layer.isHidden = false
        let start =
            from
            ?? handleFillStart(
                origin: fill.origin,
                in: bounds,
                horizontal: horizontal
            )
        layer.frame = bounds
        let left = fill.length
        guard left > 0 else { return }
        let bounding = CABasicAnimation(keyPath: "bounds")
        bounding.fromValue = CGRect(origin: .zero, size: start.size)
        bounding.toValue = CGRect(origin: .zero, size: bounds.size)
        let moving = CABasicAnimation(keyPath: "position")
        moving.fromValue = CGPoint(x: start.midX, y: start.midY)
        moving.toValue = CGPoint(x: bounds.midX, y: bounds.midY)
        let group = CAAnimationGroup()
        group.animations = [bounding, moving]
        group.duration = left
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(group, forKey: handleFillKey)
    }
}
