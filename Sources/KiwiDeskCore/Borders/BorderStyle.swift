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
/// capped-inner geometry — it eats at most `min(width/2, 1)` pt
/// of window content at any width and grows the rest outward — so
/// a thick border can't hide content (see `Borders/BorderGeometry`).
public struct BorderStyle: Sendable, Equatable {
    /// Rounded matches the real macOS window radius; Square
    /// strokes with sharp corners (radius 0). Square is seamless
    /// on already-square windows (Electron/utility) and shows an
    /// intentional corner reveal on rounded ones.
    public enum CornerStyle: String, Sendable, Codable {
        case rounded
        case square
    }

    /// The narrowest and widest the width clamps to. The command
    /// setter clamps to this exact range; the GUI slider offers
    /// whole points 1–20 (sub-point widths stay a Lua fine-tune).
    public static let minWidth: CGFloat = 0.5
    public static let maxWidth: CGFloat = 20

    /// The width at which a square border's outer edge meets the
    /// window edge. Below it a square sits inset *inside* the
    /// window (the corner is still covered by the tuck, it just
    /// doesn't hug the edge); above it, it extends outward like a
    /// frame. Not a clamp — the GUI shows a hint at thinner square
    /// widths rather than forbidding them. Tied to the real corner
    /// radius times the tuck depth (`R · squareCornerTuck`) so it
    /// tracks the true value — one shared constant with the
    /// renderer, so the hint can't drift from what's drawn (#311).
    public static var minSquareWidth: CGFloat {
        (GeometryUtils.systemWindowCornerRadius
            * BorderGeometry.squareCornerTuck).rounded(.up)
    }

    public var enabled = true
    /// Ring width (pt). Raw here; callers clamp to
    /// `minWidth...maxWidth` (`clampedWidth`).
    public var width: CGFloat = 2
    /// Accent blue, macOS's own focus-cue color.
    public var focusedColor = "#0A84FF"
    public var unfocusedEnabled = false
    /// A subtle translucent grey — present without competing with
    /// the focused ring for attention.
    public var unfocusedColor = "#00000033"
    public var cornerStyle: CornerStyle = .rounded

    public init() {}

    /// The width actually rendered — raw `width` clamped into
    /// range so a hand-edited profile can't paint an absurd ring.
    public var clampedWidth: CGFloat {
        min(Self.maxWidth, max(Self.minWidth, width))
    }

    /// Layout gaps sized so rings never touch a neighbour: the
    /// border's true **outward reach** at the screen edge and
    /// between windows, doubled between windows when both
    /// neighbours are ringed (`unfocusedEnabled`), plus an
    /// optional `remaining` gap of deliberate whitespace kept
    /// after the reach on every edge and axis (#295). Uses
    /// `BorderGeometry.outwardReach` (not the raw width) so square
    /// — which tucks inward and reaches far less than its width —
    /// isn't over-provisioned. Shared by the `border.fit_gaps`
    /// command and the GUI action so they can't drift. A one-shot
    /// convenience — `remaining` is an action parameter, never a
    /// persisted setting, and the layout math itself stays free of
    /// any border coupling (AGENTS.md §5).
    public func fittingGaps(remaining: CGFloat = 0) -> Gaps {
        let reach = BorderGeometry.outwardReach(
            width: clampedWidth,
            cornerStyle: cornerStyle
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
    }
}
