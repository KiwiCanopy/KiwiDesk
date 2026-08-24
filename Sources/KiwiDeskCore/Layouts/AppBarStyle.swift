import CoreGraphics
import Foundation

/// The app bar's global look, shared by every layout that
/// shows a bar (monocle, scrolling). Stored top-level as
/// `app_bar` in profile JSON, set from Lua via `app_bar.set_*`.
/// A layout may
/// override any of these fields for itself (see `LayoutAppBar`);
/// what isn't overridden inherits from here.
///
/// Two things deliberately live *outside* this type because they
/// are layout-specific, not looks: whether the bar is shown
/// (`LayoutAppBar.enabled`) and the focus/scroll axis
/// (`MonocleParams.orientation` / `ScrollingParams.orientation`).
public struct AppBarStyle: Sendable, Equatable {
    /// The absolute screen edge the bar occupies (#293) — no
    /// longer derived from the layout's axis.
    ///
    /// Bottom by default (#660), mirroring the Dock, while the
    /// Space Bar takes the top beside the menu bar. The two
    /// persistent strips land where macOS has already taught the
    /// eye to look for one.
    public var edge: AppBarEdge = .bottom
    /// Item-group placement along the bar; center matches the
    /// pre-#293-QA shipped behavior.
    public var alignment: BarAlignment = .center
    /// Depth of the reserved strip (pt).
    public var thickness: CGFloat = 32
    /// Plain by default (#660): one shared plate reads as a
    /// system strip the way the menu bar and Dock do, where a
    /// box per item reads as a widget laid over the desktop.
    public var backgroundStyle: BackgroundStyle = .plain
    /// Liquid Glass finish (macOS 26+), orthogonal to the shape:
    /// a colorless glass material laid over the Boxed boxes or the
    /// Plain plate. Ignored below macOS 26 (`glassEnabled`). Fill
    /// is still forwarded as the glass tint, though the tint reads
    /// near-colorless on current macOS (#390).
    public var liquidGlass: Bool = false
    /// Hug by default: a tight plate reads calmer than an
    /// edge-to-edge strip (ui-designer, QA 2026-07-19).
    public var backgroundFit: BackgroundFit = .hug
    public var activeIndicator: ActiveIndicator = .outline
    /// Item length along the bar (pt) — every item is the
    /// same size. 0 (default) = a standard length per
    /// `content`: a compact square for icon-only, wider once
    /// text is shown. Clamped at layout time between the icon
    /// square (icons never clip) and a quarter of the bar;
    /// items that overflow anyway scroll instead of shrinking.
    public var itemSize: CGFloat = 0
    /// Spacing between boxes (pt); 0 = touching.
    public var itemGap: CGFloat = 6
    public var content: Content = .iconAndTitle
    /// Longest title an item draws, in characters; longer ones
    /// tail-truncate to it with an ellipsis. Read through
    /// `resolvedTitleCap`, which clamps to `titleCapRange`.
    ///
    /// Not cosmetic. Slots are uniform and auto-sized to the
    /// WIDEST item (`AppBarOverlay.autoSlotWidth`), so one long
    /// title widens every slot until `slotLength`'s quarter-bar
    /// clamp bites and the rest of the bar scrolls — and because
    /// the measurement re-runs per render, an uncapped bar also
    /// breathes on every keystroke in an editor. Titles observed
    /// on a real desktop ran to 57 characters (owner 2026-08-19)
    /// against app names of 6–20, which is the whole reason this
    /// knob exists and `item_size` alone does not answer it.
    /// Tail truncation, deliberately: the apps that do repeat
    /// their own name in the title append it ("… — Obsidian
    /// 1.13.7"), so the tail is the byte worth losing first.
    public var titleCap = 25
    /// Where app icons come from: the native app image, or a
    /// monochrome SketchyBar App Font glyph that follows the
    /// bar's text colors (#294). Apps without a glyph keep
    /// their image.
    public var iconSource: BarAppIconSource = .appImage
    /// Adjacent windows of the same app collapse into one
    /// item wearing a count badge. Clicking the group
    /// focuses its first member, which expands the group
    /// into individual items; focus leaving the group
    /// collapses it again. Non-adjacent windows of the same
    /// app stay separate items.
    public var groupAdjacentWindows = true
    /// 0 (default) = auto: the text scales with the bar
    /// thickness. Any positive value pins the size.
    public var fontSize: CGFloat = 0
    /// Corner rounding as a percentage (0–100) of the maximum:
    /// 100 = a full capsule (radius = thickness/2), 0 = square.
    /// Resolved to a concrete radius in
    /// `resolvedCornerRadius(forThickness:)`. Percentage, not
    /// pt, so it can't exceed thickness/2 (which rendered items
    /// as pointed hexagons) and self-adapts to any thickness.
    public var cornerRoundness: CGFloat = 50
    /// Opacity of an inactive item's untinted icon (0.05–1). The dim
    /// carries "not focused" for content that takes no state color.
    /// Lua-only power knob (`set_dim_factor`, no GUI); the default
    /// matches `BarAccent.untintedAlpha`. Clamped in `resolvedDim`.
    public var dimFactor: CGFloat = BarAccent.untintedAlpha
    /// KiwiCanopy theme: ink-on-dark item text, a translucent
    /// cool-dark surface fill (box, plate, or glass tint), a
    /// kiwi-green active accent. Bars own their backdrop, so the
    /// fill-only brand green is legible here; content overlays
    /// (focus ring, drag ghost) paint over arbitrary windows and
    /// are decoupled to a contrast-tuned teal — see BorderStyle
    /// and DragVisual. Defaults here are mirrored as examples in
    /// docs/lua-reference.md (App Bar colors) — change both.
    public var itemColor = "#EAF3EE"
    /// The fill under the items — a box per item (Boxed), one
    /// shared plate (Plain), or the Liquid Glass tint
    /// (Material). One knob, three renders.
    ///
    /// 70% opaque (#755, retuning #660's 80%). #660's argument
    /// stands whole: the old 40% was legible over a dark
    /// wallpaper and a guess anywhere else, and which wallpaper
    /// a user has is not something a default can know — so the
    /// default takes the reading that holds over all of them and
    /// leaves the translucent look to anyone who wants it. Only
    /// the number moved, once all nine bundled palettes could be
    /// read side by side: bar legibility is not a per-theme
    /// preference, so every bar fill KiwiDesk ships is the same
    /// alpha, and 70% is where the readable ones had converged.
    /// `PaletteBarFillTests` holds this and the eight authored
    /// palettes to it.
    public var fillColor = "#14201CB3"
    public var activeItemColor = "#8DB354"
    public var highlightColor = "#8DB354"
    /// Hover feedback on clickable (non-active) items: a
    /// lighter, translucent kiwi green, deliberately a shade
    /// off the highlight so hover and active never read as
    /// the same state.
    public var hoverFillColor = "#AACB5D80"
    /// Item text/glyph while hovered; defaults to the normal
    /// item color (the hover tint is translucent, so the text
    /// stays readable through it) — the knob exists for themes
    /// whose hover tint needs darker text.
    public var hoverItemColor = "#EAF3EE"
    /// The count badge on grouped items. Neutral grey, not the
    /// notification red it shipped as until #955: a count of
    /// windows is state, not news, and an alert hue on every
    /// grouped item at rest reads as urgency that is not there.
    /// A theme is free to pick a hue; the DEFAULT is not.
    public var groupBadgeColor = "#636366"
    public var groupBadgeTextColor = "#FFFFFF"

    public init() {}

    /// The concrete corner radius (pt) for an item/strip of the
    /// given cross dimension: `cornerRoundness`% of its half —
    /// 100% is a capsule, 0% square. One resolution site shared
    /// by the item box, the shared strip, the scroll arrows, and
    /// the GUI preview so they can't drift.
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }

    /// Guards a dim factor to a legible, sane range — the only
    /// restriction on the Lua-only knob (a fully invisible or >1
    /// alpha is a bug, not a preference). No ordering is enforced
    /// across the Space Bar's two factors: Lua users may set what
    /// they want; the GUI is the curated gate, Lua the open one.
    public static func clampDim(_ value: CGFloat) -> CGFloat {
        max(0.05, min(value, 1))
    }

    /// The Liquid Glass finish is painted only where the platform
    /// can render it — false below macOS 26 even if `liquidGlass`
    /// is stored true, so a glass profile opened on older macOS
    /// shows the solid shape (the toggle is hidden there too).
    public var glassEnabled: Bool {
        liquidGlass && Self.glassAvailable
    }

    /// An item paints its own box: the Boxed shape without the
    /// glass finish. Plain (shared plate) and any glass finish
    /// draw no per-item box, so item fill/accent geometry that
    /// keyed on "boxed" keys on this instead.
    public var hasBox: Bool {
        backgroundStyle == .boxed && !glassEnabled
    }

    /// Whether the shared plate spans its whole strip
    /// edge-to-edge (`background_fit: full` on a style that
    /// draws a shared plate at all). The SETTINGS PREVIEWS'
    /// one copy of the spans rule — both strip mocks and the
    /// fused scene consult it. The LIVE bars resolve fit one
    /// layer further down (`BarPlate.frame`, which adds the
    /// hug→full fallback on overflow), so a retune of the
    /// rule touches this and `BarPlate` together.
    /// `SpaceBarStyle.plateSpans` is the same rule on the
    /// twin struct.
    public var plateSpans: Bool {
        !hasBox && backgroundFit == .full
    }
}

// MARK: - Codable

extension AppBarStyle: Codable {
}
