import AppKit
import QuartzCore
import SwiftUI

/// The small clear drop: it falls onto the card, squashes as it
/// lands, then sinks in under a ripple (#3038 ▸ Ruling 2026-11-23).
/// Core Animation layers, so the render server plays each step from
/// one commit, leaving the main thread free while it falls (#3700).
/// Each step names its Reduce Motion gate in its argument; gated, a
/// step lands at its end at once.
@MainActor
final class LookPickerDropView: NSView {
    /// The drop and its ripple; internal for the suite's reads.
    let drop = CALayer()
    let ripple = CAShapeLayer()
    private let body = CAGradientLayer()
    private let rim = CAShapeLayer()
    private let outline = CAShapeLayer()
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

    /// Hand-made layers take no backing scale of their own, so each
    /// follows the window's, or a 2x screen draws them soft.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        for layer in [drop, ripple, body, rim, outline] {
            layer.contentsScale = scale
        }
    }

    /// Places the drop above `point`, the card's centre in the
    /// picker's top-left coordinates, hidden.
    func prepare(landingAt point: CGPoint) {
        // Its bottom, the anchor, sits half its height below the
        // centre, so the drop's middle lands on the card's.
        target = CGPoint(
            x: point.x,
            y: bounds.height - point.y - Self.height / 2
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
    func fall(reduceMotion: Bool) {
        animate(
            drop,
            "opacity",
            to: 1,
            .easeOut,
            reduceMotion ? nil : LookPickerReveal.dropFade
        )
        animate(
            drop,
            "position",
            to: NSValue(point: target),
            .easeIn,
            reduceMotion ? nil : LookPickerReveal.fall
        )
    }

    /// Squashes on a short, bouncy spring as it lands.
    func squash(reduceMotion: Bool) {
        let to = Self.scale(Self.squashed)
        guard !reduceMotion else {
            return Self.still { drop.transform = to }
        }
        let spring = CASpringAnimation(keyPath: "transform")
        spring.mass = 1
        spring.stiffness = Self.squashStiffness
        spring.damping = Self.squashDamping
        spring.duration = spring.settlingDuration
        spring.fromValue = drop.presentation()?.transform ?? drop.transform
        spring.toValue = NSValue(caTransform3D: to)
        Self.still { drop.transform = to }
        drop.add(spring, forKey: "transform")
    }

    /// Sinks into the card under a spreading ripple.
    func sink(reduceMotion: Bool) {
        let time = reduceMotion ? nil : LookPickerReveal.sink
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
        let size = CGSize(width: Self.size, height: Self.height)
        let ink = NSColor(SettingsTheme.plateInk)
        drop.bounds = CGRect(origin: .zero, size: size)
        // Scaled about its bottom, as it lands on it.
        drop.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.frame = drop.bounds
        body.type = .radial
        // Its highlight at (0.34, 0.28) from the top, fading out
        // over the drop's width.
        body.startPoint = CGPoint(x: 0.34, y: 0.72)
        body.endPoint = CGPoint(x: 1.34, y: 0.72 + Self.size / Self.height)
        body.colors = [0.95, 0.25, 0.4].map {
            ink.withAlphaComponent($0).cgColor
        }
        outline.path = CGPath(ellipseIn: drop.bounds, transform: nil)
        body.mask = outline
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
    /// which it keeps; a nil `duration` lands there at once.
    private func animate(
        _ layer: CALayer,
        _ key: String,
        to value: Any,
        _ curve: CAMediaTimingFunctionName,
        _ duration: TimeInterval?
    ) {
        guard let duration else {
            return Self.still { layer.setValue(value, forKeyPath: key) }
        }
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
    /// A spring of response 0.12 s and damping fraction 0.55 at unit
    /// mass: (2π / response)² and 4π · fraction / response.
    static let squashStiffness: CGFloat = pow(2 * .pi / 0.12, 2)
    static let squashDamping: CGFloat = 4 * .pi * 0.55 / 0.12
    static let size: CGFloat = 34
    static let height = size * 1.3
    /// How far the sink's ripple spreads.
    static let ripple: CGFloat = 46
}
