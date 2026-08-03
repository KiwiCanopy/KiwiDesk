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
    /// A NON-ZERO `textContainerInset` on purpose. With it zero,
    /// `textContainerOrigin` is the identity and dropping the
    /// container→view conversion in `linkRects()` changed
    /// nothing a test could see — the hit area would silently
    /// sit beside the glyphs for any caller that insets.
    private static let inset = NSSize(width: 12, height: 5)

    /// `width` is a parameter because the one-line and wrapped
    /// cases assert different things, and the wrapped case is
    /// the one this whole bridge exists for (`ja`/`ko`/`zh` do
    /// not break on spaces, so the link lands mid-paragraph).
    private static func caption(
        width: CGFloat = 600,
        linkTitle: String = link,
        label: String = link
    ) -> CaptionTextView {
        let view = CaptionTextView()
        view.isEditable = false
        view.isSelectable = false
        view.textContainerInset = inset
        view.textContainer?.lineFragmentPadding = 0
        view.frame = NSRect(x: 0, y: 0, width: width, height: 60)
        view.linkLabel = label
        view.textContainer?.containerSize = CGSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: leading))
        text.append(
            NSAttributedString(
                string: linkTitle,
                attributes: linkTitle.isEmpty
                    ? [:]
                    : [
                        .link: URL(
                            string: "kiwidesk-settings://x"
                        )!
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
                length: (linkTitle as NSString).length
            )
        )
        view.layoutManager?.ensureLayout(
            for: view.textContainer!
        )
        return view
    }

    private static func linkColor(
        _ view: CaptionTextView
    ) -> NSColor? {
        view.textStorage?.attribute(
            .foregroundColor,
            at: (leading as NSString).length,
            effectiveRange: nil
        ) as? NSColor
    }

    @Test func theLinkHasAHitAreaAndItIsNotEverything() {
        let view = Self.caption()
        let rects = view.linkRects()
        // A rect list that came back empty would make every
        // `contains` below false and the "misses" assertions
        // pass for the wrong reason — the shape that would ship
        // a caption with no clickable link at all.
        #expect(!rects.isEmpty)
        // Seeded with the first rect. `reduce(NSRect.zero)`
        // unions in the point (0,0) — the exact mistake that
        // shipped in `focusRingMaskBounds`, and it bit this
        // assertion too before the anchors below caught it.
        let hit = rects.dropFirst().reduce(rects[0]) {
            $0.union($1)
        }
        #expect(hit.width > 0)
        // And not the whole caption: a hit area covering the
        // sentence would make the pointing hand and the click
        // fire over ordinary prose, which is the affordance
        // failure this file guards.
        #expect(hit.width < view.bounds.width)
        // The rects are in VIEW coordinates, not the text
        // container's. Anchored to the fixture's inset because
        // that is the one number `linkRects()` does not supply:
        // every other assertion here is relative to the rects
        // themselves, so dropping the container→view conversion
        // shifts them all uniformly and stays green. Without the
        // conversion a caller that insets gets a hit area beside
        // its own glyphs.
        #expect(hit.minY >= Self.inset.height)
        #expect(hit.minX >= Self.inset.width)
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

    /// The ring hugs the link rather than the sentence.
    ///
    /// Asserted as a CONTAINMENT, never by recomputing the
    /// property's own expression: the first cut of this test did
    /// exactly that — `linkRects().reduce(NSRect.zero)` on both
    /// sides — so the two agreed with each other and with
    /// nothing else, and stayed green over a real bug.
    /// `NSRect.zero` is a rect AT the origin rather than an
    /// empty one, so the reduce unioned in (0,0) and the shipped
    /// mask ran from the view's left edge across the whole
    /// leading prose. This form reds on that.
    @Test func theFocusRingHugsTheLinkAndNotTheSentence() throws {
        let view = Self.caption()
        let link = try #require(view.linkRects().first)
        let ring = view.focusRingMaskBounds
        #expect(ring.minX >= link.minX)
        #expect(ring.maxX <= link.maxX)
        #expect(ring.width > 0)
        #expect(ring.minX > view.bounds.minX)
    }

    /// A link that WRAPS — the case the AppKit bridge exists
    /// for, since the languages that put the name mid-sentence
    /// are the ones that do not break on spaces. The one-line
    /// assertions above are stated as a width bound, which a
    /// wrapped link legitimately fails, so it needs its own.
    @Test func aWrappedLinkKeepsAHitAreaOnEveryLine() throws {
        // The longest link the app ships, at a width that
        // forces it over two lines.
        let view = Self.caption(
            width: 120,
            linkTitle: "Layout Defaults ▸ Scrolling"
        )
        let rects = view.linkRects()
        #expect(rects.count > 1, "fixture no longer wraps")
        for rect in rects {
            #expect(
                view.isOverLink(
                    NSPoint(x: rect.midX, y: rect.midY)
                )
            )
        }
        // Distinct lines, so this is really per-line geometry
        // and not one rect reported twice.
        #expect(Set(rects.map(\.minY)).count == rects.count)
    }

    /// A caption with somewhere to go is a tab stop; one that is
    /// greyed is not, and neither is one with no link at all —
    /// both halves, because only the `isLive` half was proven
    /// and dropping the other left a linkless caption in the
    /// key-view loop with nothing to activate.
    @Test func onlyALiveCaptionWithALinkTakesFocus() {
        let view = Self.caption()
        #expect(view.acceptsFirstResponder)
        view.isLive = false
        #expect(!view.acceptsFirstResponder)
        #expect(!Self.caption(linkTitle: "").acceptsFirstResponder)
    }

    /// The pointing hand is what says a caption is followable,
    /// and every route to it needs a window — so the DECISION is
    /// asserted instead. Greyed means arrow even over the link.
    @Test func onlyALiveLinkWantsThePointingHand() throws {
        let view = Self.caption()
        let link = try #require(view.linkRects().first)
        let onLink = NSPoint(x: link.midX, y: link.midY)
        let onProse = NSPoint(x: link.minX / 2, y: link.midY)
        #expect(view.wantsPointingHand(at: onLink))
        #expect(!view.wantsPointingHand(at: onProse))
        view.isLive = false
        #expect(!view.wantsPointingHand(at: onLink))
    }

    /// Nothing in the tree asserted a caption's COLOUR, so a
    /// `setSentence` that never painted would ship the link as
    /// plain prose with every test still green — and the greyed
    /// half of `isLive` is a colour claim too.
    @Test func theLinkIsPaintedAndGreysWithTheCaption() {
        let view = Self.caption()
        #expect(Self.linkColor(view) == .secondaryLabelColor)
        view.isLive = false
        #expect(Self.linkColor(view) == .secondaryLabelColor)
    }

    /// VoiceOver gets a link child with the destination's name
    /// and a press that navigates — the reachability a
    /// non-selectable `NSTextView` supplies to nobody.
    @Test func theLinkIsAnAccessibilityChildThatActivates()
        throws
    {
        let view = Self.caption()
        var fired = 0
        view.onLink = { fired += 1 }
        let children = try #require(view.accessibilityChildren())
        #expect(children.count == 1)
        let element = try #require(
            children.first as? LinkAccessibilityElement
        )
        #expect(element.accessibilityLabel() == Self.link)
        #expect(element.accessibilityRole() == .link)
        #expect(element.accessibilityPerformPress())
        #expect(fired == 1)
        // A caption with no link offers no child to activate.
        #expect(
            Self.caption(linkTitle: "", label: "")
                .accessibilityChildren() == nil
        )
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
