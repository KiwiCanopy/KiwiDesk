import AppKit

/// What a click on a Space Bar glyph or `+n` asks for (#1528).
/// The item hands it over; Core decides between a switch-and-focus
/// and the list — the peek, or for VoiceOver the menu — so the view
/// carries no policy.
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
    /// Where the peek or a menu opens; the target view itself.
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
    /// VoiceOver's press: Core opens a list's native menu at the
    /// target — the peek's accessible twin (#1946) — and picks a
    /// one-window glyph, as a click does.
    var accessibilityPress: @MainActor (SpaceBarGlyphPick) -> Void = {
        _ in
    }
    /// Pops a menu at its target as a context menu, the chrome the
    /// bar's right-click menu wears (#1850) — modal, so a test
    /// swaps it.
    var present: @MainActor (NSMenu, NSView) -> Void = { menu, anchor in
        guard let event = SpaceBarGlyphActions.contextEvent(at: anchor)
        else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: anchor)
    }

    /// A context-menu event at `anchor`'s lower-left corner, so the
    /// menu opens at the cell whatever input picked it.
    static func contextEvent(at anchor: NSView) -> NSEvent? {
        guard let window = anchor.window else { return nil }
        let corner = NSPoint(
            x: 0,
            y: anchor.isFlipped ? anchor.bounds.maxY : 0
        )
        return NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: anchor.convert(corner, to: nil),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )
    }

    /// A click on a list — a multi-window glyph or `+n` — shows its
    /// peek at once and pins it (#1946); nothing else pins.
    func pinPeek(_ pick: SpaceBarGlyphPick) {
        guard let target = pick.anchor as? SpaceBarGlyphTarget,
            let item = target.superview as? SpaceBarItemView
        else { return }
        peek?.pin(
            target,
            source: target.peekSource,
            space: pick.space,
            edge: item.style.edge
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

    /// A press arms the pick; the peek stays, since a list's click
    /// pins it (#1946). A Control-click's menu closes it as any
    /// menu does.
    override func mouseDown(with event: NSEvent) {
        guard !openControlClickMenu(event) else { return }
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
        actions?.accessibilityPress(pick)
        return true
    }
}
