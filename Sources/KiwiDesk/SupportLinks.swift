import Foundation
import KiwiDeskCore

/// External support/branding links (#68 §3.9).
enum SupportLinks {
    /// The Ko-fi page, linked from the About card.
    ///
    /// This comment used to claim two surfaces — "quick menu +
    /// About" — and the quick menu has no support row, so it
    /// named a call site that does not exist. Nothing counts
    /// call sites, which is why a claim like that survives; the
    /// sentence is now just what the constant IS.
    static let koFi = URL(
        string: "https://ko-fi.com/kiwicanopy"
    )!

    /// The GitHub Releases page — KiwiDesk's changelog (#570).
    ///
    /// The releases ARE the changelog: this repo ships no
    /// `CHANGELOG.md`, and Sparkle — which would show notes on
    /// update — is not in the tree, so before this link the app
    /// could not tell a user what changed anywhere at all.
    ///
    /// **Linked for the notes, not as a download.**
    /// `docs/design-decisions.md` ▸ "No distribution channel
    /// without an update path" forbids advertising the Release
    /// ZIP as a direct download until Sparkle ships, and that
    /// rule governs what a surface PROMOTES; the ruling that a
    /// notes-labelled link does not open a download channel is
    /// in that same file, next to the rule it qualifies. So the
    /// label stays about the notes — do not retitle this to
    /// "Download" or point it at a release asset.
    static let releases = URL(
        string:
            "https://github.com/KiwiCanopy/KiwiDesk/releases"
    )!

    /// The written guide, in the app's own language where the
    /// site has that route (#1019).
    ///
    /// **`/guide/`, not `/docs/user-guide/`** — the two are
    /// different documents for different readers, and the
    /// sentence pointing here is read by someone who has just
    /// finished the tour. `/guide/` is the site's single-page
    /// newcomer guide; the docs tree is the canonical reference,
    /// reachable from it and written for a reader who already
    /// knows what a tiling manager is.
    ///
    /// **Only `de` and `ja` are localized, and that list is the
    /// SITE's fact, not the app's.** KiwiDesk ships eleven
    /// catalogs; the site has three locales. A path may only be
    /// treated as localized once its route genuinely exists
    /// (`site/src/pages/sitemap.xml.ts` carries the same rule for
    /// the same reason), so everything else falls back to
    /// English — a live English page beats a 404 in the reader's
    /// own language. The guard that holds this list against the
    /// site is `scripts/check-site-tokens.py` ▸
    /// `check_guide_routes`, on the SITE gate: `site/**` is
    /// CI-ignored, so a Swift assertion about a site path would
    /// go stale on exactly the change that falsifies it.
    /// `GuideLinkRouteTests` holds the app's own half — the
    /// narrowing, and that `site.yml` still watches this file.
    ///
    /// A locale gaining a site route does NOT red: the app keeps
    /// sending that reader to English until someone adds it here,
    /// which is the safe direction to be stale in.
    @MainActor static var guide: URL {
        guide(for: localizedRoute)
    }

    /// Split from ``guide`` so the routing is assertable without
    /// a live `LocalizationManager` selection.
    static func guide(for route: String?) -> URL {
        guard let route, guideRoutes.contains(route) else {
            return site.appendingPathComponent(
                "guide",
                isDirectory: true
            )
        }
        return
            site
            .appendingPathComponent(route, isDirectory: true)
            .appendingPathComponent("guide", isDirectory: true)
    }

    /// The site locales, which is a shorter list than the app's.
    static let guideRoutes: Set<String> = ["de", "ja"]

    private static let site = URL(
        string: "https://kiwidesk.kiwicanopy.com/"
    )!

    /// The effective GUI locale narrowed to what the site
    /// serves — `nil` meaning English, as it does everywhere else
    /// in this app.
    ///
    /// `LocalizationManager.effectiveLocale` already answers
    /// "which catalog is in effect", explicit pick and system
    /// language alike, so nothing here re-derives the language.
    @MainActor private static var localizedRoute: String? {
        LocalizationManager.shared.effectiveLocale
    }
}
