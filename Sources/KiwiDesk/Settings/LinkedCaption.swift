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
/// **Replacing a `Button` means re-earning what a `Button` gave
/// away free**, and the first cut of this file did not: focus,
/// keyboard activation and VoiceOver are non-negotiable under
/// gui.md's north star however much the window's look is
/// KiwiDesk's own, and a non-selectable `NSTextView` supplies
/// none of them. `CaptionTextView` puts all three back by hand —
/// see its own docs — and honours `isEnabled`, which `.disabled()`
/// sets in the SwiftUI environment and cannot reach an AppKit
/// subview on its own.
///
/// Follows `LuaSourceEditor` (`Components/Lua/LuaEditorTab.swift`)
/// as the tree's existing `NSTextView` bridge.
struct LinkedCaption: NSViewRepresentable {
    let leading: String
    let linkTitle: String
    let trailing: String
    let navigate: () -> Void
    /// `.disabled()` is environment-only, so an `NSView` inside a
    /// representable keeps its own tracking areas and hit
    /// testing and would stay live inside a `GreyOut`. Read here
    /// and handed down.
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> CaptionTextView {
        // Every caption property lives in `configured()`,
        // which the test fixture builds through as well and
        // `LinkedCaptionHitTests` asserts. A
        // SELECTABLE text view cannot be talked out of the
        // I-beam: it drives the cursor from its own tracking
        // area, which outranks the cursor rects a subclass can
        // set, and an I-beam over a caption says "type here"
        // (observed on device 2026-08-03, after
        // `resetCursorRects` was tried and lost).
        let view = CaptionTextView.configured()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(
        _ view: CaptionTextView,
        context: Context
    ) {
        view.onLink = navigate
        view.linkLabel = linkTitle
        view.isLive = isEnabled
        view.setSentence(sentence, linkRange: linkRange)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

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

    /// The link's characters within ``sentence``.
    private var linkRange: NSRange {
        NSRange(
            location: (leading as NSString).length,
            length: (Self.tightened(linkTitle) as NSString).length
        )
    }

    /// Built here rather than converted from an
    /// `AttributedString`: SwiftUI's attribute scope and
    /// AppKit's do not name these attributes the same way, and a
    /// silently unmapped `.link` would render as plain text that
    /// still passes every test asserting the sentence's words.
    ///
    /// The link's underline is set on the RUN rather than
    /// through `linkTextAttributes`, which a non-selectable view
    /// does not apply. `.link` stays on it as the marker the hit
    /// test reads; `CaptionTextView` owns the colour, which
    /// lifts on hover.
    private var sentence: NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: leading))
        out.append(
            NSAttributedString(
                string: Self.tightened(linkTitle),
                attributes: [
                    .link: Self.href,
                    .underlineStyle: NSUnderlineStyle.single
                        .rawValue,
                ]
            )
        )
        out.append(NSAttributedString(string: trailing))
        out.addAttributes(
            [
                .font: NSFont.preferredFont(
                    forTextStyle: .caption1
                )
            ],
            range: NSRange(location: 0, length: out.length)
        )
        return out
    }

    /// A `▸` breadcrumb carries a break opportunity on each side,
    /// so "Layout Defaults ▸ Scrolling" could start a line on
    /// "▸ Scrolling" under a hanging underline, which reads as a
    /// typo. Bound the separator with non-breaking spaces HERE
    /// rather than in the catalogs: it is invisible to
    /// translators, and it leaves the title breakable elsewhere,
    /// which the German and Russian ones need at the narrowest
    /// window width.
    private static func tightened(_ title: String) -> String {
        title.replacingOccurrences(
            of: " ▸ ",
            with: "\u{00A0}▸\u{00A0}"
        )
    }

    /// A run needs a URL to BE a link. Nothing resolves this
    /// scheme — the app registers no `CFBundleURLTypes` — so
    /// every activation route is wired to `onLink` instead,
    /// `clickedOnLink` included, and none of them opens it.
    private static let href = URL(
        string: "kiwidesk-settings://cross-reference"
    )!

    final class Coordinator: NSObject, NSTextViewDelegate {
        /// The path an accessibility activation and any
        /// AppKit-offered "Open Link" take. Returning `true`
        /// claims the click so the unresolvable URL above is
        /// never handed to the workspace.
        func textView(
            _ view: NSTextView,
            clickedOnLink link: Any,
            at index: Int
        ) -> Bool {
            (view as? CaptionTextView)?.activateLink()
            return true
        }
    }
}
