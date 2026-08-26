import AppKit
import KiwiDeskCore
import SwiftUI

/// The app's one pointer at the written guide (#1019).
///
/// The tour's closing card ends by saying Settings is optional —
/// *"If this is your first tiling manager, you do not need it
/// today"* — which is the right message and stays. What was
/// missing is where to go when they DO want more: nothing in the
/// app named the guide at all, so a user who finished the tour
/// and later wanted to make the setup theirs had to find the site
/// on their own.
///
/// **One sentence, two surfaces, and the three facts live here.**
/// The banner exists because a user who skipped the tour, or
/// finished it months ago, meets the closing card never — and
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
    /// The prose's size and resting ink — the tour's closing note
    /// is 13 pt `ink3`, the banner's lede one tier down. Passed
    /// rather than defaulted so neither call site reads a tier
    /// apart from the copy above it.
    let pointSize: CGFloat
    let ink: Color

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
        L("common.guide_hint", "Want to learn more? Read %1$@.")
    }

    /// The destination, named the way the site names it — the
    /// German page is titled "Handbuch", so a reader who clicks
    /// "Handbuch" lands on a page called "Handbuch".
    @MainActor static var label: String {
        L("common.read_guide", "the guide")
    }

    /// The one place the guide URL is opened.
    @MainActor static func open() {
        NSWorkspace.shared.open(SupportLinks.guide)
    }
}
