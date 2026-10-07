import AppKit

/// What a click on a Space Bar glyph or `+n` asks for (#1528).
/// The item hands it over; Core decides between a switch-and-focus
/// and a menu, so the view carries no policy.
struct SpaceBarGlyphPick {
    enum Kind: Equatable {
        /// An app glyph: the windows it stands for, in row order.
        case glyph
        /// The `+n` badge: the windows the chip did not draw.
        case overflow
    }

    let space: SpaceID
    let windows: [WindowID]
    let kind: Kind
    /// Where a menu opens; the target view itself.
    let anchor: NSView
}

/// Core's answers for the glyph targets, set once at bootstrap and
/// shared by every item — one object rather than a closure chain
/// threaded view → overlay → manager.
@MainActor
final class SpaceBarGlyphActions {
    var pick: @MainActor (SpaceBarGlyphPick) -> Void = { _ in }
    /// The bars' one hover peek (#1946), which reads its content
    /// when it shows, so a title is current without the bar
    /// re-rendering on every title change (#1514).
    weak var peek: BarPeek?
    /// Pops a menu at its target as a context menu, the chrome the
    /// bar's right-click menu wears (#1850) — modal, so a test
    /// swaps it.
    var present: @MainActor (NSMenu, NSView) -> Void = { menu, anchor in
        guard
            let event = SpaceBarGlyphActions.contextEvent(
                at: anchor,
                menu: menu.size
            )
        else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: anchor)
    }

    /// A context-menu event where a `menu`-sized menu meets the
    /// peek's bar-side edge for `anchor` — so the menu's rows land
    /// where the peek's were (#1946) — or at `anchor`'s lower-left
    /// corner for a view no peek reads, so the menu opens at the
    /// cell whatever input picked it.
    static func contextEvent(
        at anchor: NSView,
        menu: CGSize
    ) -> NSEvent? {
        guard let window = anchor.window else { return nil }
        let corner = NSPoint(
            x: 0,
            y: anchor.isFlipped ? anchor.bounds.maxY : 0
        )
        let location =
            peekMenuTopLeft(of: anchor, menu: menu)
            .map(window.convertPoint(fromScreen:))
            ?? anchor.convert(corner, to: nil)
        return NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )
    }
}

extension SpaceBarGlyphActions {
    /// Where a `menu`-sized menu's top-left stands against the peek
    /// a glyph target shows, or would; nil for any other view.
    static func peekMenuTopLeft(
        of anchor: NSView,
        menu: CGSize
    ) -> CGPoint? {
        guard let target = anchor as? SpaceBarGlyphTarget,
            let item = target.superview as? SpaceBarItemView,
            let peek = target.actions?.peek
        else { return nil }
        return peek.menuTopLeft(
            for: target,
            source: target.peekSource,
            edge: item.style.edge,
            menu: menu
        )
    }
}

/// One click target on a Space Bar item (#1528): a transparent
/// view laid over a glyph cell or the `+n` badge. The drawing
/// views beneath stay untouched, so their ink and baseline guards
/// measure what they always did.
final class SpaceBarGlyphTarget: NSView {
    let space: SpaceID
    /// The windows this target stands for, in row order.
    let members: [WindowID]
    let kind: SpaceBarGlyphPick.Kind
    weak var actions: SpaceBarGlyphActions?
    /// A press this target took, owed its pick on the release.
    private var pressed = false

    init(
        space: SpaceID,
        windows: [WindowID],
        kind: SpaceBarGlyphPick.Kind,
        label: String
    ) {
        self.space = space
        members = windows
        self.kind = kind
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// The pick this target sends; the click and VoiceOver's
    /// press both take it.
    var pick: SpaceBarGlyphPick {
        SpaceBarGlyphPick(
            space: space,
            windows: members,
            kind: kind,
            anchor: self
        )
    }

    /// What the peek shows for this target (#1946).
    var peekSource: BarPeekSource {
        kind == .glyph ? .glyph(members) : .overflow(members)
    }

    /// A press closes the peek, so a multi-window glyph's list
    /// visibly becomes its menu on the release (#1946); a
    /// Control-click's menu closes it as any menu does.
    override func mouseDown(with event: NSEvent) {
        guard !openControlClickMenu(event) else { return }
        actions?.peek?.dismiss()
        pressed = true
    }

    /// A click picks on its release inside the target (#2044): a
    /// menu popped on the press reads that release as a miss and
    /// closes. Dragging away cancels, as a button does.
    override func mouseUp(with event: NSEvent) {
        defer { pressed = false }
        guard pressed, releasesInside(event) else { return }
        actions?.pick(pick)
    }

    private func releasesInside(_ event: NSEvent) -> Bool {
        guard event.window != nil else { return true }
        let point = convert(event.locationInWindow, from: nil)
        return bounds.contains(point)
    }

    override func accessibilityPerformPress() -> Bool {
        actions?.peek?.dismiss()
        actions?.pick(pick)
        return true
    }
}
