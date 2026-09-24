import AppKit

/// The Space Bar's section of one display's shelf (#293, #385,
/// #1517): it draws into `root`, which `ShelfOverlay` places on
/// the shelf's one panel over the shelf's one plate.
@MainActor
public final class SpaceBarOverlay {
    /// One Space's resolved content — or the active shortcut
    /// layer's, ahead of the Spaces (#1169).
    public struct Item {
        let identity: SpaceBarItemView.Identity
        let spaceGlyph: SpaceGlyph
        let apps: [SpaceBarItemView.App]
        let active: Bool
        /// Windows hidden past the glyph cap ("+n" badge).
        let overflow: Int
        /// Focused window is hidden past the cap (#376).
        let focusInOverflow: Bool

        init(
            space: SpaceID,
            spaceGlyph: SpaceGlyph,
            apps: [SpaceBarItemView.App],
            active: Bool,
            overflow: Int,
            focusInOverflow: Bool
        ) {
            identity = .space(space)
            self.spaceGlyph = spaceGlyph
            self.apps = apps
            self.active = active
            self.overflow = overflow
            self.focusInOverflow = focusInOverflow
        }

        /// The layer item: one glyph, no apps, never active.
        init(
            layer: String,
            glyph: SpaceGlyph
        ) {
            identity = .layer(layer)
            spaceGlyph = glyph
            apps = []
            active = false
            overflow = 0
            focusInOverflow = false
        }

        var space: SpaceID? { identity.space }
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }

    /// The section's view; the shelf sets its origin, the
    /// section its size.
    let root = AppBarOverlay.FlippedView()
    /// The plate this section's run asks for, in `root`'s
    /// coordinates — the shelf unions it with the other section's.
    var plateFrame: CGRect = .zero
    /// Fires after every render, so the shelf re-lays its plate.
    var onRendered: @MainActor () -> Void = {}
    var itemViews: [SpaceBarItemView] = []
    /// Clipping item viewport (#385).
    let itemContainer = AppBarOverlay.FlippedView()
    let backArrow = BarArrowView()
    let forwardArrow = BarArrowView()
    /// Host view for front-app segment (#409).
    weak var frontHost: NSView?
    /// Per-box Liquid Glass views for `boxed + liquid_glass`.
    var boxGlasses: [NSView] = []
    /// Colored backdrops behind per-box glass (#408).
    var boxTints: [NSView] = []
    /// Front-app segment frosted backdrop box.
    var frontGlass: NSView?
    /// Colored backdrop behind front segment glass (#408).
    var frontTint: NSView?
    /// Whole-bar scroll offset (#385).
    var scrollOffset: CGFloat = 0
    /// Cached scroll geometry for hit-testing and autoscroll (#385).
    var scrollGeom: ScrollGeom?
    /// Running drag-autoscroll task when dwelling on an arrow
    /// zone (#385). A `Task` loop, not a `Timer`: a `Timer`'s
    /// `@Sendable` block cannot weak-capture this non-`Sendable`
    /// `@MainActor` type in a release build.
    var autoScrollTask: Task<Void, Never>?
    var autoScrollDirection: ScrollArrow?
    /// Last-rendered strip in AX coordinates and the per-item
    /// frames within it (strip-local, top-left), for the #372
    /// drag-drop hit test. Kept in lockstep with what `render()`
    /// drew — clamped to the visible viewport so a point over an
    /// arrow zone or a scrolled-off item is never a drop target.
    var hitStrip: CGRect = .zero
    var hitFrames: [(space: SpaceID, frame: CGRect)] = []
    /// Section rule after the layer item (#1169).
    let layerDivider: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.isHidden = true
        return view
    }()
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
            style: SpaceBarLook,
            stateMarkColors: StateMarkColors
        )?

    public init() {
        configureRoot()
    }

    public var isVisible: Bool { lastShown != nil && !root.isHidden }

    /// Renders `items` into `strip` in AX coordinates.
    func show(
        items: [Item],
        frontApp: SpaceBarItemView.App? = nil,
        strip: CGRect,
        style: SpaceBarLook,
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
        root.isHidden = true
        onRendered()
    }

    /// Content run start for given alignment (#293 QA, #385).
    nonisolated static func contentStart(
        total: CGFloat,
        axis: CGFloat,
        alignment: KiwiShelf.Alignment,
        pad: CGFloat
    ) -> CGFloat {
        switch alignment {
        case .start: return pad
        case .center: return max((axis - total) / 2, pad)
        case .end: return max(axis - total - pad, pad)
        }
    }
}
