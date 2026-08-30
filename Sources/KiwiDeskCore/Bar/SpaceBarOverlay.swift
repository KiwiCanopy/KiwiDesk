import AppKit

/// Space Bar overlay panel for one display in AX coordinates (#293, #385).
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
        /// Focused window is hidden past the cap (#376).
        let focusInOverflow: Bool
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }

    var panel: NSPanel?
    var itemViews: [SpaceBarItemView] = []
    /// Clipping item viewport (#385).
    let itemContainer = AppBarOverlay.FlippedView()
    let backArrow = BarArrowView()
    let forwardArrow = BarArrowView()
    /// Host view for front-app segment (#409).
    weak var frontHost: NSView?
    /// Liquid Glass plate for material background (#390).
    var glassPlate: NSView?
    /// Per-box Liquid Glass views for `boxed + liquid_glass`.
    var boxGlasses: [NSView] = []
    /// Colored backdrops behind per-box glass (#408).
    var boxTints: [NSView] = []
    /// Front-app segment frosted backdrop box.
    var frontGlass: NSView?
    /// Colored backdrop behind front segment glass (#408).
    var frontTint: NSView?
    /// Colored backdrop behind single glass plate (#408).
    var glassTint: NSView?
    /// Backdrop filler view for glass hosting (#409).
    let glassBackdropFiller = NSView()
    /// Flipped run wrapper for plain + glass without overflow.
    var glassRun: AppBarOverlay.FlippedView?
    /// Shared fill plate for plain style (`background_fit`, QA 2026-07-19).
    var plainPlate: NSView?
    /// Whole-bar scroll offset (#385).
    var scrollOffset: CGFloat = 0
    /// Cached scroll geometry for hit-testing and autoscroll (#385).
    var scrollGeom: ScrollGeom?
    /// Running drag-autoscroll task when dwelling on arrow zone (#385).
    var autoScrollTask: Task<Void, Never>?
    var autoScrollDirection: ScrollArrow?
    /// Last-rendered strip in AX coordinates and the per-item
    /// frames within it (strip-local, top-left), for the #372
    /// drag-drop hit test. Kept in lockstep with what `render()`
    /// drew — clamped to the visible viewport so a point over an
    /// arrow zone or a scrolled-off item is never a drop target.
    var hitStrip: CGRect = .zero
    var hitFrames: [(space: SpaceID, frame: CGRect)] = []
    // Optional trailing front-app segment (#293).
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

    /// Renders `items` into `strip` in AX coordinates.
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

    /// True if overlay panel is visible on screen.
    var isPanelVisible: Bool { panel?.isVisible == true }

    /// Content run start for given alignment (#293 QA, #385).
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
