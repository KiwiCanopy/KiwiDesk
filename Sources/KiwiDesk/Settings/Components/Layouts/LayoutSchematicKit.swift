import KiwiDeskCore
import SwiftUI

/// The shared visual grammar of the Layout Defaults schematics
/// (#125): the mini-canvas metrics, the accent tile language, the
/// two ghost conventions, and the damping applied when a staged
/// value changes. One family, so every mode's schematic — and the
/// `GapsDiagram` it echoes — reads as one set. Everything here is
/// pure SwiftUI drawing over the staged config: no live state, no
/// AX calls (the #123 never-live-apply principle — a schematic
/// answers "what would this look like", it never touches the
/// running session).
enum LayoutSchematic {
    static let canvasWidth: CGFloat = 140
    static let canvasHeight: CGFloat = 96
    static let corner: CGFloat = 3
    static let inset: CGFloat = 6
    static let fill = SettingsTheme.accent.opacity(0.25)
    static let stroke = SettingsTheme.accent.opacity(0.6)

    /// Short enough to track a live slider drag without visible
    /// lag; still smooths stepper/typed jumps. Mirrors
    /// `GapsDiagram`.
    static let damping = Animation.easeOut(duration: 0.12)

    /// The window count the live preview opens on, and the band
    /// the slider offers. The floor is **2**, not 1: with a
    /// single window every one of the seven layouts draws the
    /// same full-screen rectangle, so a 1 tells the reader
    /// nothing about the layout they picked — and it is the one
    /// count at which several schematics have no second zone to
    /// draw. The ceiling is where the canvas stops telling a
    /// story and starts drawing slivers.
    static let defaultWindowCount = 5
    static let windowCountRange = 2...12

    /// How far a piled tile reveals the one beneath it. The
    /// engine's `OverlapStack` uses 40 pt against a real display;
    /// on a canvas this size that would throw tiles off the frame,
    /// so the reveal is scaled to the canvas. Shared by every
    /// schematic that piles — Stack's zone, Track's overflow track
    /// and Grid's last cell — because a pile that reads as a pile
    /// in one and as a colour in another is the same picture
    /// telling two stories (#712).
    static let cascadeOffset: CGFloat = 9

    /// The Grid preview's stand-in for the one ceiling it cannot
    /// compute: `auto_size`, where `GridLayout.capDimensions`
    /// fits as many minimum-size cells as the *display* allows.
    /// The canvas is not a display and has no minimum window
    /// size, so it draws a plausible grid and the caption states
    /// these numbers rather than prose (#712).
    ///
    /// With auto-size **off** no stand-in is needed: the ceiling
    /// is the user's own typed columns × rows.
    ///
    /// **A schematic's ceiling is the engine's rule, never the
    /// canvas's.** An earlier cut of #712 also clamped the
    /// ceiling to what the canvas could legibly draw, which made
    /// the drawn *capacity* scale-dependent: rigid 8 × 1 with
    /// five windows drew a two-window pile on the strip
    /// thumbnail and none in the panel, inventing an overflow
    /// the engine does not have. Clamp the drawing if you must;
    /// never the rule.
    static let gridAutoSizeCap = (columns: 3, rows: 3)

}

/// How large a schematic draws — and therefore what it is *for*
/// (turn 10 of the #678 redesign).
///
/// `tile` is a thumbnail in the "Choose a layout" strip: one
/// fixed size for every layout so the strip reads as a row
/// rather than a ransom note, with the schematic's own caption
/// suppressed — a tile is titled by its layout's name and the
/// count of spaces using it, which the strip owns. `panel` is
/// the live preview below the rows: it fills the pane, so a
/// layout has room to be *read* rather than merely recognised.
///
/// One deliberate loss at `tile`: a schematic that needs more
/// canvas than a thumbnail has to make its argument makes it at
/// the panel and not on the thumbnail. BSP widens its own frame
/// to 3:1, where "cut the longer side" and "alternate" only
/// diverge after several cuts. Scrolling keeps its frame and
/// gives up the *margin* instead — the room its off-monitor
/// ghosts need — so a tile spends its whole canvas on the
/// monitor rather than drawing it at half every sibling's scale
/// (#753, `LayoutSchematicScaleTests`). A thumbnail answers
/// "which of these do I want?"; the argument is one click away,
/// and a strip of seven different-shaped tiles would answer
/// neither question.
///
/// `CaseIterable` for the same reason `ScrollingParams.Anchor`
/// is: a third scale has to satisfy every claim a caption makes
/// about the frame, and a hand-listed sweep would go on passing
/// over two of three (#753).
enum SchematicScale: Hashable, CaseIterable {
    case tile
    case panel

    /// `nil` means "fill the width available" — the panel spans
    /// its pane, so the preview grows with the window.
    var width: CGFloat? {
        self == .tile ? 132 : nil
    }

    var height: CGFloat {
        self == .tile ? 84 : 240
    }

    var showsCaption: Bool { self == .panel }
}

/// Value-domain math shared by the schematics, kept apart from
/// the SwiftUI drawing so the mapping stays unit-testable (like
/// `GapPreviewScale`).
enum SchematicMath {
    /// A 0...1 ratio as a rounded whole percent, for a11y prose.
    static func pct(_ ratio: Double) -> Int {
        Int((ratio * 100).rounded())
    }

    /// Maps an explicit slot-size in points onto a 0.15...0.6
    /// fraction of the mini-canvas, so the scrolling schematic's
    /// tiles read narrower or wider without a real screen.
    static func slotFraction(points: CGFloat) -> CGFloat {
        let t = (points - 100) / (1200 - 100)
        return 0.15 + 0.45 * min(max(t, 0), 1)
    }
}

/// One schematic tile in the family fill/stroke language. The
/// `active` variant carries a heavier stroke for a highlighted
/// slot (the scrolling anchor, the focused track).
struct SchematicTile: View {
    var active = false

    var body: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(LayoutSchematic.fill)
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    LayoutSchematic.stroke,
                    lineWidth: active ? 2 : 1
                )
            )
    }
}

/// A small "+N" chip on the last visible tile when a schematic
/// caps how many windows it draws.
struct SchematicMoreChip: View {
    let hidden: Int

    var body: some View {
        Text("+\(hidden)")
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 3)
            .background(
                Capsule().fill(Color(nsColor: .textBackgroundColor))
            )
    }
}

/// An **empty cell** — permanently unused space a rigid grid
/// leaves when it has more cells than windows. Dashed, gray:
/// reads as "no window here", distinct from the spawn ghost
/// (a *future* window) and the off-monitor ghost (a *real*
/// window off-screen).
struct SchematicGap: View {
    var body: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .strokeBorder(
                Color.secondary.opacity(0.4),
                style: StrokeStyle(lineWidth: 1, dash: [3, 2])
            )
    }
}

/// **New-window tile** — "the next window lands here." Stays in
/// the accent family (it *is* a window) but reads bolder than a
/// real tile: a denser fill (0.45 vs 0.25) plus a "+" corner
/// badge that carries the meaning even without colour. The badge,
/// not the fill alone, is the signal — so it survives low-
/// contrast / colour-blind viewing. Used where a mode's new-
/// window placement is the point (BSP, Stack, Grid, Track). Kept
/// deliberately distinct from the gray `SchematicGap`
/// (permanently-empty) and `SchematicGhostOverflow` (off-screen):
/// accent family = a window; gray family = not a window.
struct SchematicNewWindow: View {
    /// Which corner the "+" badge sits in. Defaults to the bottom-
    /// trailing corner; the scrolling schematic overrides it so the
    /// badge stays in the visible half when the new-window tile is
    /// cropped by the canvas edge (a first/last window).
    var badgeAlignment: Alignment = .bottomTrailing

    var body: some View {
        ZStack(alignment: badgeAlignment) {
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .fill(SettingsTheme.accent.opacity(0.45))
                .overlay(
                    RoundedRectangle(
                        cornerRadius: LayoutSchematic.corner
                    )
                    .strokeBorder(
                        LayoutSchematic.stroke,
                        lineWidth: 1
                    )
                )
            Image(systemName: "plus")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
                .padding(2)
        }
    }
}

/// **Piled tile** — one window in an `OverlapStack` cascade, where
/// only its top edge shows above the next.
///
/// Drawn **opaque**: a solid base under the accent fill, so
/// stacking never sums the accent alpha. That is the whole reason
/// this is a type rather than a `SchematicTile` drawn twice — the
/// Grid preview piled translucent tiles at one rect and the last
/// cell simply *got bluer* with the count instead of showing
/// windows (#712), the same compounding-opacity trap as #406.
/// Stack and Track each had a correct private copy; Grid needed a
/// third, which is one more than a look this load-bearing should
/// have (§2.4).
///
/// The front tile of a pile carries the dominant colour and the
/// buried ones read as lighter slivers behind it.
struct SchematicPileTile: View {
    /// A heavier stroke for the focused window in the pile.
    var active = false
    /// The "+" badge, when this piled window is the incoming one.
    var isNew = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .fill(Color(nsColor: .textBackgroundColor))
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .fill(
                    isNew
                        ? SettingsTheme.accent.opacity(0.45)
                        : LayoutSchematic.fill
                )
            RoundedRectangle(cornerRadius: LayoutSchematic.corner)
                .strokeBorder(
                    LayoutSchematic.stroke,
                    lineWidth: active ? 2 : 1
                )
            if isNew {
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(2)
            }
        }
    }
}

/// **Off-monitor ghost** — a *real* window scrolled or overflowed
/// past the visible screen. Solid gray fill, thin solid stroke,
/// drawn straddling / outside the monitor rectangle. No "+"
/// (that would collide with the spawn ghost). Used by Scrolling.
struct SchematicGhostOverflow: View {
    var body: some View {
        RoundedRectangle(cornerRadius: LayoutSchematic.corner)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                RoundedRectangle(
                    cornerRadius: LayoutSchematic.corner
                )
                .strokeBorder(
                    Color.secondary.opacity(0.5),
                    lineWidth: 1
                )
            )
    }
}
