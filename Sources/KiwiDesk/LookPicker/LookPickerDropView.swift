import AppKit
import QuartzCore
import SwiftUI

/// The small clear drop: it falls onto the card, squashes as it
/// lands, then sinks in under a ripple (#3038 ▸ Ruling 2026-11-23).
/// Drawn in Core Animation layers, not SwiftUI (#3700): each step is
/// one commit the render server plays, where a SwiftUI fall committed
/// every frame on the main thread and lost about every other frame
/// at 120 Hz on device. The controller calls the steps only past its
/// Reduce Motion branch, which takes the cross-fade instead.
@MainActor
final class LookPickerDropView: NSView {
    /// The drop and its ripple; internal for the suite's reads.
    let drop = CALayer()
    let ripple = CAShapeLayer()
    private let body = CAGradientLayer()
    private let rim = CAShapeLayer()
    /// Where it lands, in the view's own unflipped points.
    private var target = CGPoint.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Drawn only, never hit, so every click reaches the picker.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { false }

    /// Places the drop above `point`, the card's centre in the
    /// picker's top-left coordinates, hidden.
    func prepare(landingAt point: CGPoint) {
        // Its bottom, the anchor, sits half its height below the
        // centre, as SwiftUI's `.position` placed its frame.
        target = CGPoint(
            x: point.x,
            y: bounds.height - point.y - Self.size * 1.3 / 2
        )
        let centre = CGPoint(x: point.x, y: bounds.height - point.y)
        Self.still {
            drop.opacity = 0
            drop.position = above
            drop.transform = Self.scale(Self.falling)
            ripple.position = centre
            ripple.opacity = 0
            ripple.path = Self.ellipse(width: 0, height: 0)
        }
    }

    /// Fades in at the top and falls onto the card.
    func fall() {
        animate(drop, "opacity", to: 1, .easeOut, LookPickerReveal.dropFade)
        animate(
            drop,
            "position",
            to: NSValue(point: target),
            .easeIn,
            LookPickerReveal.fall
        )
    }

    /// Squashes on a short, bouncy spring as it lands.
    func squash() {
        let spring = CASpringAnimation(keyPath: "transform")
        spring.mass = 1
        spring.stiffness = Self.squashStiffness
        spring.damping = Self.squashDamping
        spring.duration = spring.settlingDuration
        let to = Self.scale(Self.squashed)
        spring.fromValue = drop.presentation()?.transform ?? drop.transform
        spring.toValue = NSValue(caTransform3D: to)
        Self.still { drop.transform = to }
        drop.add(spring, forKey: "transform")
    }

    /// Sinks into the card under a spreading ripple.
    func sink() {
        let time = LookPickerReveal.sink
        animate(
            drop,
            "transform",
            to: NSValue(caTransform3D: Self.scale(Self.sunk)),
            .easeOut,
            time
        )
        animate(drop, "opacity", to: 0, .easeOut, time)
        Self.still { ripple.opacity = 1 }
        animate(
            ripple,
            "path",
            to: Self.ellipse(
                width: Self.ripple * 2,
                height: Self.ripple * 0.8
            ),
            .easeOut,
            time
        )
        animate(ripple, "opacity", to: 0, .easeOut, time)
    }

    private var above: CGPoint {
        CGPoint(
            x: target.x,
            y: target.y + LookPickerReveal.dropHeight
        )
    }

    private func build() {
        let size = CGSize(width: Self.size, height: Self.size * 1.3)
        let ink = NSColor(SettingsTheme.plateInk)
        drop.bounds = CGRect(origin: .zero, size: size)
        // Scaled about its bottom, as it lands on it.
        drop.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.frame = drop.bounds
        body.type = .radial
        // SwiftUI's (0.34, 0.28) from the top, its radius the size.
        body.startPoint = CGPoint(x: 0.34, y: 0.72)
        body.endPoint = CGPoint(x: 1.34, y: 0.72 + 1 / 1.3)
        body.colors = [0.95, 0.25, 0.4].map {
            ink.withAlphaComponent($0).cgColor
        }
        let shape = CAShapeLayer()
        shape.path = CGPath(ellipseIn: drop.bounds, transform: nil)
        body.mask = shape
        rim.path = CGPath(
            ellipseIn: drop.bounds.insetBy(dx: 0.5, dy: 0.5),
            transform: nil
        )
        rim.fillColor = nil
        rim.strokeColor = ink.withAlphaComponent(0.55).cgColor
        rim.lineWidth = 1
        drop.addSublayer(body)
        drop.addSublayer(rim)
        ripple.fillColor = nil
        ripple.strokeColor = ink.withAlphaComponent(0.8).cgColor
        ripple.lineWidth = 1.5
        layer?.addSublayer(ripple)
        layer?.addSublayer(drop)
        drop.opacity = 0
        ripple.opacity = 0
    }

    /// Animates `key` of `layer` from where it is drawn now to `value`,
    /// which it keeps.
    private func animate(
        _ layer: CALayer,
        _ key: String,
        to value: Any,
        _ curve: CAMediaTimingFunctionName,
        _ duration: TimeInterval
    ) {
        let motion = CABasicAnimation(keyPath: key)
        motion.fromValue =
            layer.presentation()?.value(forKeyPath: key)
            ?? layer.value(forKeyPath: key)
        motion.toValue = value
        motion.duration = duration
        motion.timingFunction = CAMediaTimingFunction(name: curve)
        Self.still { layer.setValue(value, forKeyPath: key) }
        layer.add(motion, forKey: key)
    }

    /// Runs `change` with no implicit animation.
    private static func still(_ change: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        change()
        CATransaction.commit()
    }

    private static func scale(_ s: (x: CGFloat, y: CGFloat)) -> CATransform3D {
        CATransform3DMakeScale(s.x, s.y, 1)
    }

    /// An ellipse `width` by `height` centred on the layer's origin.
    private static func ellipse(width: CGFloat, height: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(
                x: -width / 2,
                y: -height / 2,
                width: width,
                height: height
            ),
            transform: nil
        )
    }

    static let falling: (x: CGFloat, y: CGFloat) = (0.85, 1.15)
    static let squashed: (x: CGFloat, y: CGFloat) = (1.3, 0.7)
    static let sunk: (x: CGFloat, y: CGFloat) = (0.2, 0.1)
    /// SwiftUI's `.spring(response: 0.12, dampingFraction: 0.55)` at
    /// unit mass: (2π / response)² and 4π · fraction / response.
    static let squashStiffness: CGFloat = pow(2 * .pi / 0.12, 2)
    static let squashDamping: CGFloat = 4 * .pi * 0.55 / 0.12
    static let size: CGFloat = 34
    /// How far the sink's ripple spreads.
    static let ripple: CGFloat = 46
}
