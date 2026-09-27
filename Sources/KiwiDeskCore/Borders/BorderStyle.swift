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
    /// Default 5: the largest width that still tiles cleanly with
    /// unfocused rings on — each ring reaches `width` into the
    /// 10 pt inner gap, so 2 × 5 fills it edge-to-edge; 6 would
    /// overlap.
    public var width: CGFloat = 5
    /// Focused ring colour (#578: shifted ~12° off the brand hue
    /// to escape the moss cast while clearing the 3:1 floor both
    /// ways; docs/lua-reference.md mirrors the default — change
    /// both). The drag ghost deliberately is NOT this family
    /// (#511: it must separate from the drop-zone amber under
    /// red-green vision loss) — do not re-converge them.
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
    /// The painted sheen (#1644) on the focused ring, the shelf's
    /// highlight and border, and the drag markers' borders: a signed
    /// strength in `sheenRange` — positive lightens the top,
    /// negative darkens it, 0 draws none.
    public var sheen: CGFloat = 0.5

    /// The sheen's range; every writer clamps into it.
    public static let sheenRange: ClosedRange<CGFloat> = -1...1

    /// `value` clamped into `sheenRange`, anything under half the
    /// readout's last digit (0.01%) snapped to 0: a slider's float
    /// grid lands on Off, and a value the readout would print as
    /// "+0%" draws nothing either, so the two agree.
    public static func clampSheen(_ value: CGFloat) -> CGFloat {
        let clamped = min(
            sheenRange.upperBound,
            max(sheenRange.lowerBound, value)
        )
        return abs(clamped) < sheenSnap ? 0 : clamped
    }

    /// Half the readout's resolution, as a strength.
    static let sheenSnap: CGFloat = 0.00005

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

    /// The blur a ring carries — the ONE home of "which ring
    /// blooms" (#358): the focused ring's resolved blur, the
    /// unfocused ring's none, read by the renderer's specs and
    /// by `fittingGaps` alike (#1378, `FitGapsGlowTests`).
    public func glowBlur(focused: Bool) -> CGFloat {
        focused ? resolvedGlowBlur : 0
    }

    /// Width clamped to valid range.
    public var clampedWidth: CGFloat {
        min(Self.maxWidth, max(Self.minWidth, width))
    }

    /// Computes gaps fitting border widths without overlap (#295).
    /// A one-shot convenience: `remaining` is an action parameter,
    /// never a persisted setting, and the layout math itself stays
    /// free of any border coupling (AGENTS.md §5). The glow joins
    /// ONCE, on the focused side (#1378): only one side of an inner
    /// gap is focused, and the unfocused ring has no bloom.
    public func fittingGaps(remaining: CGFloat = 0) -> Gaps {
        let focused = BorderGeometry.outwardReach(
            width: clampedWidth,
            glowBlur: glowBlur(focused: true)
        ).rounded(.up)
        let unfocused = BorderGeometry.outwardReach(
            width: clampedWidth,
            glowBlur: glowBlur(focused: false)
        ).rounded(.up)
        let extra = max(0, remaining)
        let outer = focused + extra
        let inner =
            focused + (unfocusedEnabled ? unfocused : 0) + extra
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
        case sheen
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
        sheen = Self.clampSheen(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .sheen
            ) ?? defaults.sheen
        )
    }
}
