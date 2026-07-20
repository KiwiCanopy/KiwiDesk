import CoreGraphics
import Foundation

/// The focused-window border look (#278), stored top-level as
/// `border` in profile JSON and set from Lua via `border.set_*`.
/// A thin ring KiwiDesk paints around the focused window (and,
/// when `unfocusedEnabled`, every other managed window) so the
/// active window is unmistakable in a gapped grid — the feedback
/// loop keyboard-driven focus otherwise lacks.
///
/// The ring is a pure post-layout overlay: it never feeds back
/// into layout math (no gap coupling). The stroke uses a
/// hidden-overlap geometry — the configured width grows entirely
/// outward, with an additional renderer-only overlap behind the
/// target. The target masks that overlap, so a thick border cannot
/// hide content (see `Borders/BorderGeometry`).
public struct BorderStyle: Sendable, Equatable {
    /// Rounded matches the real macOS window radius; Square
    /// strokes with sharp corners (radius 0). Square is seamless
    /// on already-square windows (Electron/utility) and shows an
    /// intentional corner reveal on rounded ones.
    public enum CornerStyle: String, Sendable, Codable {
        case rounded
        case square
    }

    /// Where the focus ring stacks relative to windows. `behind`
    /// (the default, #319/#361) uses the flicker-free below-order
    /// AppKit path; `front` uses the crisp, shadowless above-order
    /// SkyLight path — a power-user opt-in that can flicker under
    /// the per-keystroke compositor churn Firefox/Zen emit, so it
    /// stays a Lua-only setting with no GUI toggle (#367).
    public enum DrawOrder: String, Sendable, Codable {
        case behind
        case front
    }

    /// The narrowest and widest the width clamps to. The command
    /// setter clamps to this exact range; the GUI slider offers
    /// whole points 1–20 (sub-point widths stay a Lua fine-tune).
    public static let minWidth: CGFloat = 0.5
    public static let maxWidth: CGFloat = 20

    /// The remaining-gap action range (#295), whole points —
    /// one source for the `border.fit_gaps` argument clamp and
    /// the GUI field, so the bounds cannot drift (the
    /// `targetDepthRange` pattern).
    public static let remainingGapRange: ClosedRange<Double> =
        0...100

    public var enabled = true
    /// Ring width (pt). Raw here; callers clamp to
    /// `minWidth...maxWidth` (`clampedWidth`).
    public var width: CGFloat = 2
    /// Kiwi flesh-green — the theme's focus accent, matching the
    /// bars' active/focus signal rather than macOS's generic blue.
    public var focusedColor = "#4E9F3D"
    public var unfocusedEnabled = false
    /// A subtle translucent grey — present without competing with
    /// the focused ring for attention.
    public var unfocusedColor = "#8E8E93CC"
    public var cornerStyle: CornerStyle = .rounded
    /// Ring stacked behind windows (default) or in front. A niche
    /// Lua-only preference with no GUI control (#367).
    public var drawOrder: DrawOrder = .behind

    public init() {}

    /// The width actually rendered — raw `width` clamped into
    /// range so a hand-edited profile can't paint an absurd ring.
    public var clampedWidth: CGFloat {
        min(Self.maxWidth, max(Self.minWidth, width))
    }

    /// Layout gaps sized so rings never touch a neighbour: the
    /// border's visible **outward reach** at the screen edge and
    /// between windows, doubled between windows when both
    /// neighbours are ringed (`unfocusedEnabled`), plus an
    /// optional `remaining` gap of deliberate whitespace kept
    /// after the reach on every edge and axis (#295). Uses
    /// `BorderGeometry.outwardReach`, which deliberately excludes
    /// the renderer's hidden overlap. Shared by the `border.fit_gaps`
    /// command and the GUI action so they can't drift. A one-shot
    /// convenience — `remaining` is an action parameter, never a
    /// persisted setting, and the layout math itself stays free of
    /// any border coupling (AGENTS.md §5).
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

// MARK: - Codable

extension BorderStyle: Codable {
    /// JSON keys are the Lua setters (`border.set_*`) minus the
    /// `set_` verb — the `border` nesting carries the namespace.
    /// `CaseIterable` is load-bearing: `BorderParityTests`
    /// reflects over `allCases` to prove every field has a key —
    /// do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case width
        case focusedColor = "focused_color"
        case unfocusedEnabled = "unfocused_enabled"
        case unfocusedColor = "unfocused_color"
        case cornerStyle = "corner_style"
        case drawOrder = "draw_order"
    }

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
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
        drawOrder =
            try container.decodeIfPresent(
                DrawOrder.self,
                forKey: .drawOrder
            ) ?? defaults.drawOrder
    }
}
