import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The app narrows its own catalog to the guide routes the site
/// serves (#1019).
///
/// **The cross-tree half is NOT here, and cannot be.** Whether
/// `site/src/pages/de/guide/` exists is the site's fact, and
/// `site/**` is on `.github/ci-ignore.txt` — a change confined to
/// the site skips the macOS jobs, so a Swift assertion about a
/// site path would go stale on exactly the change that falsifies
/// it, and `CiPathFilterTests` refuses the placement outright.
/// That half lives in `scripts/check-site-tokens.py` ▸
/// `check_guide_routes`, on the site gate, the way
/// `check_promoted_download` already does.
///
/// What is left here is the app's own half: that the narrowing
/// happens at all, and that it narrows to something this app can
/// actually be in.
@Suite("Guide link routes")
@MainActor
struct GuideLinkRouteTests {
    /// The app ships eleven catalogs and the site three locales,
    /// so the narrowing is the whole point of the seam — without
    /// it a `pt-BR` reader is sent to a page that does not exist.
    @Test("a catalog the site does not serve falls back")
    func unservedLocaleFallsBackToEnglish() {
        let english = SupportLinks.guide(for: nil)
        #expect(SupportLinks.guide(for: "pt-BR") == english)
        #expect(SupportLinks.guide(for: "ko") == english)
        // `absoluteString`, not `path`: `URL.path` normalises the
        // trailing slash away, and the trailing slash is what the
        // site serves — Astro's routes are directories.
        #expect(english.absoluteString.hasSuffix("/guide/"))
    }

    @Test("a served locale takes its own route")
    func servedLocaleTakesItsRoute() {
        for locale in SupportLinks.guideRoutes {
            #expect(
                SupportLinks.guide(for: locale).absoluteString
                    .hasSuffix("/\(locale)/guide/")
            )
        }
    }

    /// A route claimed for a locale the app cannot be in is dead
    /// code that reads as coverage — and it is the shape a
    /// widening typo takes. This is the app's own fact, so it is
    /// answerable here; whether the SITE serves the route is the
    /// site gate's.
    @Test("every claimed route names a catalog this app ships")
    func claimedRoutesAreShippedLocales() {
        let shipped = Set(
            LocalizationManager.shared.available
        )
        for locale in SupportLinks.guideRoutes {
            #expect(
                shipped.contains(locale),
                Comment(
                    rawValue:
                        "the app claims a \(locale) guide route "
                        + "and ships no \(locale) catalog"
                )
            )
        }
    }

    /// The narrowing is `effectiveLocale`'s answer, never a
    /// second reading of the language: an explicit pick and the
    /// system language both arrive through it, and a call site
    /// re-deriving one would disagree with every other string on
    /// the screen it is drawn on.
    @Test("the live route follows the effective locale")
    func liveRouteFollowsTheSelection() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            SupportLinks.guide == SupportLinks.guide(for: "de")
        )
        LocalizationManager.shared.select("es")
        #expect(SupportLinks.guide == SupportLinks.guide(for: nil))
    }
}
