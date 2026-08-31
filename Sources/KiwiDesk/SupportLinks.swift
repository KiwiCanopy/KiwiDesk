import Foundation
import KiwiDeskCore

/// External support and branding links (#68 §3.9).
enum SupportLinks {
    /// Ko-fi donation page.
    static let koFi = URL(
        string: "https://ko-fi.com/kiwicanopy"
    )!

    /// Main GitHub repository URL (owner ruling 2026-08-26).
    static let gitHub = URL(
        string: "https://github.com/KiwiCanopy/KiwiDesk"
    )!

    /// GitHub Releases — KiwiDesk's changelog (#570). Linked for
    /// the NOTES, not as a download: `docs/design-decisions.md` ▸
    /// "No distribution channel without an update path" governs
    /// what a surface promotes — do not retitle this to
    /// "Download" or point it at a release asset.
    static let releases = URL(
        string:
            "https://github.com/KiwiCanopy/KiwiDesk/releases"
    )!

    /// User guide URL routed by active locale (#1019). `/guide/`,
    /// not `/docs/user-guide/` — the single-page newcomer guide,
    /// for a reader who just finished the tour. A path is treated
    /// as localized only once its site route exists; everything
    /// else falls back to English — a live English page beats a
    /// 404. A locale gaining a route does NOT red: stale-to-
    /// English is the safe direction (`GuideLinkRouteTests`,
    /// `check_guide_routes`, `site.yml`).
    @MainActor static var guide: URL {
        guide(for: localizedRoute)
    }

    /// Resolves guide URL for route (/guide/, `check_guide_routes`).
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

    /// Localized site routes supported on web.
    static let guideRoutes: Set<String> = ["de", "ja"]

    private static let site = URL(
        string: "https://kiwidesk.kiwicanopy.com/"
    )!

    /// Active GUI locale string for website route selection.
    @MainActor private static var localizedRoute: String? {
        LocalizationManager.shared.effectiveLocale
    }
}
