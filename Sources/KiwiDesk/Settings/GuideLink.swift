import AppKit
import KiwiDeskCore
import SwiftUI

/// The app's one pointer at the written guide (#1019).
///
/// Nothing in the app named the written guide at all, so a user
/// who finished the tour and later wanted to make the setup
/// theirs had to find the site on their own — which is the gap
/// this closes.
///
/// **One sentence, two surfaces, and the three facts live here.**
/// The banner exists because a user who closed the tour after
/// its shortcuts screen, or finished it months ago, meets the
/// closing card never — and
/// both surfaces want the same short pointer, so it is one
/// `common.` key rather than two translations of one sentence
/// with nothing holding them together (`.claude/rules/
/// localization.md`: a key joins `common.` when the same English
/// names the same action at every call site, which this does).
///
/// The tour's closing card draws it in the page FOOTER rather
/// than through this view, `OnboardingPage` owning that slot's
/// layout — so ``prose``, ``label`` and ``open()`` are static and
/// that call site takes the three directly. There is still one
/// home for each.
///
/// The label is a NOUN, not an action — the sentence around it
/// carries the verb, so a translation can put the destination
/// wherever its own word order wants it. `CrossReferenceRow`
/// already works this way for the same reason.
///
/// `LinkedCaption`, not a `Button` or a SwiftUI `Link`: a
/// SwiftUI `.link` run gets no pointing-hand cursor (that file's
/// on-device finding), and the label rides INSIDE the sentence at
/// its own specifier so a translation places it.
///
/// **No network preflight.** `NSWorkspace.open` hands the URL to
/// the browser and the browser reports its own failure — which is
/// the honest answer, since nothing here can tell a down site
/// from a captive portal from a machine that is simply offline,
/// and a wrong "you are offline" beside a live link is worse than
/// the browser's own page. The app's other two external links
/// (`SupportLinks`) make the same trade.
struct GuideLink: View {
    /// The prose's size and resting ink.
    ///
    /// Defaulted to `LinkedCaption`'s own caption tier, so the
    /// call site that wants it says nothing rather than keeping a
    /// second copy of the expression that would not follow a
    /// retune. A surface whose surrounding copy sits at another
    /// tier passes its own.
    var pointSize: CGFloat = NSFont.preferredFont(
        forTextStyle: .caption1
    ).pointSize
    var ink: Color = Color(nsColor: .secondaryLabelColor)

    var body: some View {
        let parts = LinkedCaption.split(frame: Self.prose)
        LinkedCaption(
            leading: parts.0,
            linkTitle: Self.label,
            trailing: parts.1,
            navigate: Self.open,
            pointSize: pointSize,
            ink: NSColor(ink)
        )
    }

    /// The sentence, carrying `%1$@` where the guide's name goes.
    @MainActor static var prose: String {
        L(
            "common.guide_hint",
            // "Get more out of it", not "learn more" (owner,
            // 2026-08-26). The reader this sentence is for is a
            // beginner who has just been told the app is already
            // working — so the offer is what they GAIN, not the
            // reading. German led here and the English followed
            // rather than the other way round.
            "Want to get more out of it? Read %1$@."
        )
    }

    /// The destination, named the way the site names it — the
    /// German page is titled "Handbuch", so a reader who clicks
    /// "Handbuch" lands on a page called "Handbuch".
    @MainActor static var label: String {
        L("common.read_guide", "the guide")
    }

    /// Opens the guide. The sentence-shaped surfaces route here;
    /// General ▸ About draws a bare SwiftUI `Link` at the URL
    /// instead, its label BEING the destination, so there are two
    /// readers by design and `GuideLinkSurfaceTests` holds them
    /// as an exact census. Both go through `SupportLinks.guide`,
    /// which is what applies the locale narrowing — that is the
    /// thing with one home, not this function.
    @MainActor static func open() {
        NSWorkspace.shared.open(SupportLinks.guide)
    }
}
