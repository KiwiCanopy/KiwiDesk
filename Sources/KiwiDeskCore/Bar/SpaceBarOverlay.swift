import AppKit

/// The Space Bar panel for one display (#293): renders Space
/// items into a strip handed to it in AX coordinates. A dumb
/// renderer like `AppBarOverlay` — the driver resolves state,
/// identifiers, and glyphs. Items size to their content
/// (identifier + app glyphs), so lengths vary per item. When the
/// run overflows the strip the bar scrolls rather than clipping
/// (#385): items render inside a clipping viewport inset by an
/// arrow zone at each end, with clickable chevrons toward the
/// hidden Spaces and a scroll that follows the active Space — the
/// App Bar's overflow model (see `SpaceBarOverlay+Scroll`).
@MainActor
public final class SpaceBarOverlay {
    /// One Space's resolved content.
    public struct Item {
        let space: SpaceID
        let spaceGlyph: SpaceBarItemView.Identifier
        let apps: [SpaceBarItemView.App]
        let active: Bool
        /// Windows hidden past the glyph cap ("+n" badge).
        let overflow: Int
        /// The focused window is one hidden past the cap — the "+n"
        /// tints to signal focus is behind it (#376).
        let focusInOverflow: Bool
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }

    // Internal (not private): `render()` in the +Render extension
    // reads and lazily creates the panel.
    var panel: NSPanel?
    var itemViews: [SpaceBarItemView] = []
    /// The clipping item viewport (#385): items and the trailing
    /// front segment render inside it, inset by an arrow zone at
    /// each end while the run overflows, so a half-scrolled item
    /// is cut a gap short of the arrows instead of sliding under
    /// them. Spans the full strip while everything fits.
    let itemContainer = AppBarOverlay.FlippedView()
    let backArrow = BarArrowView()
    let forwardArrow = BarArrowView()
    /// Where the front-app segment's views (and its glass backdrop)
    /// are hosted this render (#409): `itemContainer` while the run
    /// fits, so the segment is the run's tail as before; the panel
    /// content (outside the clipping viewport) while the run
    /// overflows, so the segment stays pinned to the trailing rim
    /// while only the Spaces scroll behind the arrows. Set by
    /// `render()` before the front pass; read by
    /// `attachFrontViewsIfNeeded` and `updateFrontGlass`.
    weak var frontHost: NSView?
    /// The Liquid Glass plate under the items when `tabBackground`
    /// resolves to `material` (#390); nil otherwise / below macOS
    /// 26. Stored as a plain view — the concrete type is 26-only.
    var glassPlate: NSView?
    /// Per-box Liquid Glass: one `NSGlassEffectView` per Space item
    /// under `boxed + liquid_glass`, each hosting its item as
    /// `contentView` (piece 2, App Bar twin). Empty otherwise /
    /// below macOS 26. See SpaceBarOverlay+BoxGlass.
    var boxGlasses: [NSView] = []
    /// Colored backdrops behind each per-box glass (`GlassTint`,
    /// #408); parallel to `boxGlasses`, empty / below macOS 26.
    var boxTints: [NSView] = []
    /// The front-app segment's own frosted box under per-box glass.
    /// The segment is non-interactive, so this sits as a backdrop
    /// behind its loose views rather than hosting them.
    var frontGlass: NSView?
    /// Colored backdrop behind the front segment's glass (#408).
    var frontTint: NSView?
    /// Colored backdrop behind the single glass plate (#408).
    var glassTint: NSView?
    /// Throwaway content view that turns the shared plate into a
    /// bare frosted backdrop when the front app is pinned over an
    /// overflowing run (#409) — an empty content view frosts as
    /// true glass (the `frontGlass` precedent), letting the plate
    /// span the strip under both the items and the pinned segment.
    let glassBackdropFiller = NSView()
    /// Under plain + glass when the run fits, the glass hosts this
    /// flipped run wrapper at the hugged plate frame with the run
    /// (items + front segment) placed run-local — so the frosted
    /// plate hugs instead of spanning the viewport (piece 1). On
    /// overflow the glass falls back to hosting `itemContainer`.
    var glassRun: AppBarOverlay.FlippedView?
    /// `plain`'s shared fill plate — its own view (not the
    /// container layer) so it can hug the run
    /// (`tab_background_fit`, QA 2026-07-19).
    var plainPlate: NSView?
    /// Whole-bar scroll offset (#385); 0 while the run fits.
    var scrollOffset: CGFloat = 0
    /// Cached scroll geometry, kept for the arrow-zone hit test
    /// and the drag autoscroll stepping between renders (#385).
    var scrollGeom: ScrollGeom?
    /// The running drag-autoscroll task and its direction while a
    /// window drag dwells over an arrow zone (#385); nil when idle.
    /// A `Task` loop (not a `Timer`) mirrors the drop coordinator's
    /// dwell — a `Timer`'s `@Sendable` block can't weak-capture
    /// this non-`Sendable` `@MainActor` type in a release build.
    var autoScrollTask: Task<Void, Never>?
    var autoScrollDirection: ScrollArrow?
    /// Last-rendered strip in AX coordinates and the per-item
    /// frames within it (strip-local, top-left), for the #372
    /// drag-drop hit test. Kept in lockstep with what `render()`
    /// drew — clamped to the visible viewport so a point over an
    /// arrow zone or a scrolled-off item is never a drop target.
    var hitStrip: CGRect = .zero
    var hitFrames: [(space: SpaceID, frame: CGRect)] = []
    // The optional trailing front-app segment (#293 verdict 6):
    // a Boxed-only fill box behind the content, a divider rule,
    // the focused app's glyph, and — on horizontal bars only —
    // its name.
    let frontBox = NSView()
    let frontDivider = NSView()
    let frontIcon = NSImageView()
    let frontGlyph: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let frontName = NSTextField(labelWithString: "")
    // Internal (not private): read by `render()` in the +Render
    // extension.
    var lastShown:
        (
            items: [Item],
            frontApp: SpaceBarItemView.App?,
            strip: CGRect,
            style: SpaceBarStyle,
            stateMarkColors: StateMarkColors
        )?

    public init() {}

    public var isVisible: Bool { panel?.isVisible ?? false }

    /// Renders `items` into `strip` (AX coordinates).
    /// `frontApp` is the trailing segment's app; nil while the
    /// toggle is off or no window is focused.
    func show(
        items: [Item],
        frontApp: SpaceBarItemView.App? = nil,
        strip: CGRect,
        style: SpaceBarStyle,
        stateMarkColors: StateMarkColors
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        lastShown = (items, frontApp, strip, style, stateMarkColors)
        render(followingActive: true)
    }

    public func hide() {
        lastShown = nil
        hitStrip = .zero
        hitFrames = []
        scrollOffset = 0
        scrollGeom = nil
        cancelDragAutoScroll()
        panel?.orderOut(nil)
    }

    /// Whether the panel is on screen — the hit test is only
    /// meaningful for a visible bar.
    var isPanelVisible: Bool { panel?.isVisible == true }

    // MARK: - Rendering

    // `render(followingActive:)` and `activeIndex` live in
    // `SpaceBarOverlay+Render.swift` (file size, §2).

    /// Axis start of the content run per `alignment` (#293
    /// QA). `pad` keeps the run off the strip's rim and floors
    /// every case. Overflowing runs never reach this — they start
    /// at the scroll offset (#385, see `runMetrics`). `pad` is a
    /// parameter (callers pass `SpaceBarItemView.pad`) so this
    /// stays nonisolated and unit-testable.
    nonisolated static func contentStart(
        total: CGFloat,
        axis: CGFloat,
        alignment: SpaceBarStyle.Alignment,
        pad: CGFloat
    ) -> CGFloat {
        switch alignment {
        case .start: return pad
        case .center: return max((axis - total) / 2, pad)
        case .end: return max(axis - total - pad, pad)
        }
    }
}
