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
    /// Read at hover time, so a title is current without the bar
    /// re-rendering on every title change (#1514).
    var tooltip: @MainActor ([WindowID]) -> String? = { _ in nil }
    /// Pops a menu under its target — modal, so a test swaps it.
    var present: @MainActor (NSMenu, NSView) -> Void = { menu, anchor in
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: anchor.isFlipped ? anchor.bounds.maxY : 0),
            in: anchor
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
    private var tipTag: NSView.ToolTipTag?

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

    override func mouseDown(with event: NSEvent) {
        actions?.pick(pick)
    }

    override func accessibilityPerformPress() -> Bool {
        actions?.pick(pick)
        return true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let tipTag { removeToolTip(tipTag) }
        // The `+n` badge's list is its click; a glyph names itself.
        guard kind == .glyph else { return }
        tipTag = addToolTip(bounds, owner: self, userData: nil)
    }
}

extension SpaceBarGlyphTarget: NSViewToolTipOwner {
    func view(
        _ view: NSView,
        stringForToolTip tag: NSView.ToolTipTag,
        point: NSPoint,
        userData data: UnsafeMutableRawPointer?
    ) -> String {
        actions?.tooltip(members) ?? ""
    }
}
