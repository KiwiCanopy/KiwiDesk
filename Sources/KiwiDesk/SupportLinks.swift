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

    /// GitHub Releases changelog URL (`docs/design-decisions.md`, #570).
    static let releases = URL(
        string:
            "https://github.com/KiwiCanopy/KiwiDesk/releases"
    )!

    /// User guide URL routed by active locale
    /// (`GuideLinkRouteTests`, `site.yml`, #1019).
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
