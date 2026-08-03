import AppKit
import Testing

@testable import KiwiDesk

/// `LinkedCaption` exists to put the pointing hand, the click
/// and the keyboard on ONE PHRASE inside a caption rather than
/// on the whole of it. Everything downstream of that — the
/// cursor, `mouseDown`, the focus ring, the accessibility
/// child — is `linkRects()`, and nothing asserted it: the slot
/// guard covers which SENTENCE is rendered, never where the link
/// lands in it. A `linkRects()` returning the whole bounds, or
/// nothing, satisfies every other test in the tree.
///
/// Needs no machine: an `NSTextView` off-screen lays out from
/// its own text container.
///
/// `@MainActor` because `NSView` is.
@MainActor
@Suite("Linked caption hit area")
struct LinkedCaptionHitTests {
    private static let leading = "Configured in "
    private static let link = "App Bar"
    private static let trailing = " for this layout."

    /// A caption laid out at a width wide enough for one line,
    /// so "before the link" and "after the link" are horizontal
    /// and unambiguous.
    private static func caption() -> CaptionTextView {
        let view = CaptionTextView()
        view.isEditable = false
        view.isSelectable = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.frame = NSRect(x: 0, y: 0, width: 600, height: 40)
        view.textContainer?.containerSize = CGSize(
            width: 600,
            height: CGFloat.greatestFiniteMagnitude
        )
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: leading))
        text.append(
            NSAttributedString(
                string: link,
                attributes: [
                    .link: URL(string: "kiwidesk-settings://x")!
                ]
            )
        )
        text.append(NSAttributedString(string: trailing))
        text.addAttribute(
            .font,
            value: NSFont.preferredFont(forTextStyle: .caption1),
            range: NSRange(location: 0, length: text.length)
        )
        view.setSentence(
            text,
            linkRange: NSRange(
                location: (leading as NSString).length,
                length: (link as NSString).length
            )
        )
        view.layoutManager?.ensureLayout(
            for: view.textContainer!
        )
        return view
    }

    @Test func theLinkHasAHitAreaAndItIsNotEverything() {
        let view = Self.caption()
        let rects = view.linkRects()
        // A rect list that came back empty would make every
        // `contains` below false and the "misses" assertions
        // pass for the wrong reason — the shape that would ship
        // a caption with no clickable link at all.
        #expect(!rects.isEmpty)
        let hit = rects.reduce(NSRect.zero) { $0.union($1) }
        #expect(hit.width > 0)
        // And not the whole caption: a hit area covering the
        // sentence would make the pointing hand and the click
        // fire over ordinary prose, which is the affordance
        // failure this file guards.
        #expect(hit.width < view.bounds.width)
    }

    @Test func theHitAreaCoversTheLinkAndNotTheProse() throws {
        let view = Self.caption()
        let hit = try #require(view.linkRects().first)
        let midY = hit.midY
        #expect(view.isOverLink(NSPoint(x: hit.midX, y: midY)))
        // Leading prose sits to the left of the link's minX.
        #expect(
            !view.isOverLink(
                NSPoint(x: hit.minX / 2, y: midY)
            )
        )
        // Trailing prose to the right of its maxX.
        #expect(
            !view.isOverLink(
                NSPoint(x: hit.maxX + 4, y: midY)
            )
        )
    }

    /// The focus ring hugs the link rather than the sentence,
    /// which is the same geometry by a different route — if
    /// these ever disagree, one of the two affordances is
    /// pointing at the wrong words.
    @Test func theFocusRingTracksTheHitArea() {
        let view = Self.caption()
        let hit = view.linkRects().reduce(NSRect.zero) {
            $0.union($1)
        }
        #expect(view.focusRingMaskBounds == hit)
    }

    /// A caption with somewhere to go is a tab stop; one that is
    /// greyed is not, because an affordance for a channel that
    /// does not exist is removed rather than offered dead.
    @Test func onlyALiveCaptionTakesFocus() {
        let view = Self.caption()
        #expect(view.acceptsFirstResponder)
        view.isLive = false
        #expect(!view.acceptsFirstResponder)
    }

    /// `.disabled()` reaches an AppKit subview only because
    /// `LinkedCaption` hands `isEnabled` down; a greyed caption
    /// that still navigated would say "switch that on and I act"
    /// while acting anyway.
    @Test func aGreyedCaptionDoesNotNavigate() {
        let view = Self.caption()
        var fired = 0
        view.onLink = { fired += 1 }
        view.activateLink()
        #expect(fired == 1)
        view.isLive = false
        view.activateLink()
        #expect(fired == 1)
    }
}
