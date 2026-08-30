import CoreGraphics
import Foundation

/// The focused-window border look (#278), stored in profile JSON.
public struct BorderStyle: Sendable, Equatable {
    /// Corner stroke styling (rounded system radius or sharp square).
    public enum CornerStyle: String, Sendable, Codable, CaseIterable {
        case rounded
        case square
    }

    /// Focus ring stack placement (#319, #361, #367).
    public enum DrawOrder: String, Sendable, Codable, CaseIterable {
        case behind
        case front
    }

    public static let minWidth: CGFloat = 0.5
    public static let maxWidth: CGFloat = 20

    /// Gap range for `border.fit_gaps` (#295).
    public static let remainingGapRange: ClosedRange<Double> =
        0...100

    public var enabled = true
    /// Ring width in pt (clamped to `minWidth...maxWidth`).
    public var width: CGFloat = 5
    /// Focused ring color (#4A9816, #578; distinct from drag visual #511).
    public var focusedColor = "#4A9816"
    public var unfocusedEnabled = false
    public var unfocusedColor = "#8E8E93CC"
    public var cornerStyle: CornerStyle = .rounded
    /// Bloom halo around focused ring (#358).
    public var glow = false
    /// Glow blur radius in pt (0 = automatic, #551).
    public var glowSize: CGFloat = 0
    /// Stacking order (#367).
    public var drawOrder: DrawOrder = .behind

    public init() {}

    /// Maximum renderable glow size ceiling (40 pt).
    public static let maxGlowSize: CGFloat = 40

    /// Resolved blur radius for focused ring glow (#551).
    public var resolvedGlowBlur: CGFloat {
        guard glow else { return 0 }
        return glowSize > 0
            ? min(Self.maxGlowSize, glowSize)
            : Self.glowBlur(for: clampedWidth)
    }

    /// Width clamped to valid range.
    public var clampedWidth: CGFloat {
        min(Self.maxWidth, max(Self.minWidth, width))
    }

    /// Computes gaps fitting border widths without overlap (#295).
    public func fittingGaps(remaining: CGFloat = 0) -> Gaps {
        let reach = BorderGeometry.outwardReach(
            width: clampedWidth
        ).rounded(.up)
        let extra = max(0, remaining)
        let outer = reach + extra
        let inner =
            (unfocusedEnabled ? reach * 2 : reach) + extra
        return Gaps(
            outer: .init(
                top: outer,
                bottom: outer,
                left: outer,
                right: outer
            ),
            inner: .init(horizontal: inner, vertical: inner)
        )
    }
}

extension BorderStyle: Codable {
    /// CodingKeys reflect over `allCases` in `BorderParityTests`.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case width
        case focusedColor = "focused_color"
        case unfocusedEnabled = "unfocused_enabled"
        case unfocusedColor = "unfocused_color"
        case cornerStyle = "corner_style"
        case glow
        case glowSize = "glow_size"
        case drawOrder = "draw_order"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
        width =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .width
            ) ?? defaults.width
        focusedColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .focusedColor
            ) ?? defaults.focusedColor
        unfocusedEnabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .unfocusedEnabled
            ) ?? defaults.unfocusedEnabled
        unfocusedColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .unfocusedColor
            ) ?? defaults.unfocusedColor
        cornerStyle =
            try container.decodeIfPresent(
                CornerStyle.self,
                forKey: .cornerStyle
            ) ?? defaults.cornerStyle
        glow =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .glow
            ) ?? defaults.glow
        glowSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .glowSize
            ) ?? defaults.glowSize
        drawOrder =
            try container.decodeIfPresent(
                DrawOrder.self,
                forKey: .drawOrder
            ) ?? defaults.drawOrder
    }
}
