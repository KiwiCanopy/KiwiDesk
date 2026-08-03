import AppKit
import SwiftUI

/// One caption sentence with a single word or phrase in it
/// rendered as a link, laid out by AppKit's text system.
///
/// SwiftUI's own `Text` can carry a `.link` run and it navigates,
/// but it gives that run no pointing-hand cursor — confirmed on
/// device 2026-08-03, which is why this exists. The cursor is
/// the affordance that says a caption is followable at all, and
/// the row this replaced had one (a `Button` wearing
/// `linkHover()`), so losing it was a regression, not a trade.
///
/// AppKit is the right tool for the other half too. This sentence
/// exists so a translation can place the destination's name where
/// its own word order wants it, which means the name can land
/// mid-paragraph, which means the paragraph has to break lines
/// correctly around it in `ja`, `ko`, `zh-Hans` and `zh-Hant` —
/// languages that do not break on spaces. `NSLayoutManager` does
/// that; a `FlowLayout` over word-split `Text`s does not, and it
/// would fail hardest for exactly the locales the change is for.
///
/// Follows `LuaSourceEditor` (`Components/Lua/LuaEditorTab.swift`)
/// as the tree's existing `NSTextView` bridge.
struct LinkedCaption: NSViewRepresentable {
    let leading: String
    let linkTitle: String
    let trailing: String
    let navigate: () -> Void

    func makeNSView(context: Context) -> CaptionTextView {
        let view = CaptionTextView()
        view.isEditable = false
        // A SELECTABLE text view cannot be talked out of the
        // I-beam: it drives the cursor from its own tracking
        // area, which outranks the cursor rects a subclass can
        // set, and an I-beam over a caption says "type here"
        // (observed on device 2026-08-03, after
        // `resetCursorRects` was tried and lost). So the view is
        // not selectable, and `CaptionTextView` owns the click
        // and the cursor outright — AppKit routes link clicks
        // through the selection machinery it no longer has.
        view.isSelectable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        return view
    }

    func updateNSView(
        _ view: CaptionTextView,
        context: Context
    ) {
        view.onLink = navigate
        view.textStorage?.setAttributedString(sentence)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: CaptionTextView,
        context: Context
    ) -> CGSize? {
        guard
            let width = proposal.width,
            width > 0,
            width < .greatestFiniteMagnitude,
            let container = nsView.textContainer,
            let manager = nsView.layoutManager
        else { return nil }
        container.containerSize = CGSize(
            width: width,
            height: .greatestFiniteMagnitude
        )
        manager.ensureLayout(for: container)
        return CGSize(
            width: width,
            height: ceil(manager.usedRect(for: container).height)
        )
    }

    /// Built here rather than converted from an
    /// `AttributedString`: SwiftUI's attribute scope and
    /// AppKit's do not name these attributes the same way, and a
    /// silently unmapped `.link` would render as plain text that
    /// still passes every test asserting the sentence's words.
    ///
    /// The link's underline and colour are set on the RUN rather
    /// than through `linkTextAttributes`, which a non-selectable
    /// view does not apply. `.link` stays on it as the marker
    /// the hit test and VoiceOver read.
    private var sentence: NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: leading))
        out.append(
            NSAttributedString(
                string: linkTitle,
                attributes: [
                    .link: Self.href,
                    .underlineStyle: NSUnderlineStyle.single
                        .rawValue,
                ]
            )
        )
        out.append(NSAttributedString(string: trailing))
        // The caption's own colour throughout, link included —
        // never the system link blue: these pointers are prose
        // the reader may follow, not calls to action, and the
        // underline is the affordance.
        out.addAttributes(
            [
                .font: NSFont.preferredFont(
                    forTextStyle: .caption1
                ),
                .foregroundColor: NSColor.secondaryLabelColor,
            ],
            range: NSRange(location: 0, length: out.length)
        )
        return out
    }

    /// A run needs a URL to BE a link; `navigate` decides where
    /// it goes, there being exactly one link per caption.
    private static let href = URL(
        string: "kiwidesk-settings://cross-reference"
    )!
}

/// A non-selectable text view that owns its own click and
/// cursor. Both halves are here because the selectable version
/// gave the whole caption an I-beam and no way to override it.
final class CaptionTextView: NSTextView {
    var onLink: (() -> Void)?
    private var hover: NSTrackingArea?
    private var overLink = false

    /// `.mouseMoved` rather than `.cursorUpdate`: the cursor has
    /// to change as the pointer crosses from prose INTO the link
    /// within one view, and a cursor-update area only fires on
    /// entering and leaving the area itself.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hover { removeTrackingArea(hover) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseMoved,
                .mouseEnteredAndExited,
                .activeInKeyWindow,
                .inVisibleRect,
            ],
            owner: self
        )
        addTrackingArea(area)
        hover = area
    }

    override func mouseMoved(with event: NSEvent) {
        apply(isOverLink(location(of: event)))
    }

    override func mouseExited(with event: NSEvent) {
        apply(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard isOverLink(location(of: event)) else {
            super.mouseDown(with: event)
            return
        }
        onLink?()
    }

    /// A view removed under the pointer never delivers its own
    /// exit, so the arrow is restored here too — the imbalance
    /// `NSCursor.set()` exists to survive (gui.md, SwiftUI
    /// traps). `set()`, never push/pop.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { apply(false) }
    }

    private func apply(_ overLink: Bool) {
        guard overLink != self.overLink else { return }
        self.overLink = overLink
        (overLink ? NSCursor.pointingHand : NSCursor.arrow).set()
    }

    private func location(of event: NSEvent) -> NSPoint {
        convert(event.locationInWindow, from: nil)
    }

    private func isOverLink(_ point: NSPoint) -> Bool {
        linkRects().contains { $0.contains(point) }
    }

    private func linkRects() -> [NSRect] {
        guard
            let storage = textStorage,
            let manager = layoutManager,
            let container = textContainer
        else { return [] }
        let origin = textContainerOrigin
        var rects: [NSRect] = []
        storage.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: storage.length)
        ) { value, range, _ in
            guard value != nil else { return }
            let glyphs = manager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            manager.enumerateEnclosingRects(
                forGlyphRange: glyphs,
                withinSelectedGlyphRange: NSRange(
                    location: NSNotFound,
                    length: 0
                ),
                in: container
            ) { rect, _ in
                rects.append(
                    rect.offsetBy(dx: origin.x, dy: origin.y)
                )
            }
        }
        return rects
    }
}
