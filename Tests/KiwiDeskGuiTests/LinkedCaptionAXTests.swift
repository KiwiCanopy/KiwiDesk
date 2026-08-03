import AppKit
import Testing

@testable import KiwiDesk

/// The accessibility surface of a caption's link, split from
/// `LinkedCaptionHitTests` on the 350-line ceiling.
///
/// It is a suite of its own rather than a few more cases because
/// the thing it watches is separable: a non-selectable
/// `NSTextView` is an `AXTextArea` with nothing activatable in
/// it, so `CaptionTextViewAX.swift` exists to put a link element
/// back, and this is what holds it there.
///
/// Shares the hit suite's fixture shape deliberately rather than
/// importing it — per-file private helpers are the convention
/// (tests.md), and the two suites assert different things about
/// the same view.
@MainActor
@Suite("Linked caption accessibility")
struct LinkedCaptionAXTests {
    private static let leading = "Configured in "
    private static let link = "App Bar"
    private static let trailing = " for this layout."

    private static func caption(
        width: CGFloat = 600,
        linkTitle: String = link,
        label: String = link
    ) -> CaptionTextView {
        let view = CaptionTextView.configured()
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
        #expect(element.isAccessibilityElement())
        #expect(element.accessibilityPerformPress())
        #expect(fired == 1)
        // ONE element, reused. `setAccessibilityParent` makes no
        // strong reference, so a fresh element per call is owned
        // only by the array it is returned in, while VoiceOver
        // queries children repeatedly and holds what it gets.
        let again = try #require(
            view.accessibilityChildren()?.first
                as? LinkAccessibilityElement
        )
        #expect(again === element)
        // A caption with no link offers no child to activate.
        // Only the CONJUNCTION of the two nil-guards is proven
        // here; either alone can be deleted green.
        #expect(
            Self.caption(linkTitle: "", label: "")
                .accessibilityChildren() == nil
        )
    }

    /// The caption reads as a group with the whole sentence on
    /// it, and the link is the one thing inside it that acts.
    /// The activatable half was proven and this half was not,
    /// which is half of why `CaptionTextViewAX.swift` exists.
    @Test func theCaptionReadsAsAGroupCarryingItsSentence() {
        let view = Self.caption()
        #expect(view.accessibilityRole() == .group)
        #expect(
            view.accessibilityLabel()
                == Self.leading + Self.link + Self.trailing
        )
    }

    /// A wrapped link's AX highlight must cover every line, like
    /// its focus ring — the frame was `linkRects().first` and
    /// nothing read a frame at all, so one line was invisible.
    @Test func aWrappedLinkGetsAnAccessibilityFrameSpanningIt()
        throws
    {
        let view = Self.caption(
            width: 120,
            linkTitle: "Layout Defaults ▸ Scrolling",
            label: "Layout Defaults ▸ Scrolling"
        )
        let rects = view.linkRects()
        #expect(rects.count > 1, "fixture no longer wraps")
        let element = try #require(
            view.accessibilityChildren()?.first
                as? LinkAccessibilityElement
        )
        let frame = element.accessibilityFrameInParentSpace()
        for rect in rects {
            #expect(frame.intersects(rect))
        }
        #expect(frame.height >= rects[0].height * 2)
    }

    /// The configuration `CaptionTextView.configured()` holds is
    /// ASSERTED, not merely shared. Routing the fixture through
    /// the factory removed the divergence between it and
    /// production; it made none of these observable, so
    /// re-selecting the caption — the single thing this class
    /// exists to prevent, and the state that puts an I-beam over
    /// a caption and hands the cursor to AppKit — still shipped
    /// green.
    @Test func theCaptionIsConfiguredAsACaption() {
        let view = CaptionTextView.configured()
        #expect(!view.isSelectable)
        #expect(!view.isEditable)
        #expect(!view.drawsBackground)
        #expect(view.focusRingType == .exterior)
        #expect(view.textContainer?.widthTracksTextView == true)
        #expect(view.textContainer?.lineFragmentPadding == 0)
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
