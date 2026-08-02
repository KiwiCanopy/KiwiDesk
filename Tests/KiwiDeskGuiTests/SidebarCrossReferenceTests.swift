import Foundation
import Testing

@testable import KiwiDesk

/// A `▸` breadcrumb names a place the user has to find, so its
/// first segment must be the string that place actually shows.
/// `behavior.animations.scrolling_xref_link` points at Layout
/// Defaults; `SidebarSearch.path` builds the same shape from
/// `destination.title`. Nothing tied the two, and the drift was
/// already shipping — `ko`, `pt-BR` and `zh-Hans` each named
/// that pane by a label no sidebar row and no search breadcrumb
/// would ever display, and `es` had drifted too.
///
/// The pairing is DERIVED, not listed here: a link key is one
/// whose ENGLISH first segment equals a destination's English
/// title, so a second cross-reference written the same way is
/// covered the day it lands. `en.json`'s other `▸` strings name
/// macOS System Settings panes, whose first segment matches no
/// destination, and are skipped by the same rule.
///
/// Reach, stated so a green run is not over-read: the FIRST
/// segment only. The tail names a layout mode, and whether a
/// locale renders that natively is
/// `docs/localization-naming.md`'s question, not this one —
/// `zh-Hant` ships the English "Scrolling" in its picker while
/// translating the word in twelve prose strings, which this
/// guard neither sees nor should decide.
///
/// A breadcrumb authored MID-SENTENCE is also outside the net:
/// its first segment is the prose before it, which matches no
/// title, so it never enters the derived set — `en.json`'s
/// `behavior.animations.master.help` is exactly that shape.
/// `theCrossReferenceIsDiscovered` pins the one link that
/// exists today; a second one written mid-sentence would be
/// dropped with nothing noticing.
@Suite("Sidebar cross-reference naming")
struct SidebarCrossReferenceTests {
    private static let separator = " ▸ "

    private static let repoRoot = SourceScan.repoRoot(
        from: #filePath
    )

    private static var localesDirectory: URL {
        repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Locales")
    }

    private static func catalog(_ name: String) throws
        -> [String: String]
    {
        try JSONDecoder().decode(
            [String: String].self,
            from: Data(
                contentsOf:
                    localesDirectory
                    .appendingPathComponent("\(name).json")
            )
        )
    }

    private static func shippedLocales() throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(atPath: localesDirectory.path)
            .filter { $0.hasSuffix(".json") }
            .filter { !$0.hasPrefix("missing_") }
            .map { String($0.dropLast(".json".count)) }
            .filter { $0 != "en" }
            .sorted()
    }

    /// Link key → the destination key whose title heads it,
    /// derived by matching each `▸` string's English first
    /// segment against the destination titles.
    private static func links() throws -> [String: String] {
        let titles = try SourceScan.sidebarTitles(root: repoRoot)
        let english = try catalog("en")
        var out: [String: String] = [:]
        for (key, value) in english {
            guard
                let head = value.components(
                    separatedBy: separator
                ).first,
                head != value,
                let title = titles.first(where: {
                    $0.english == head
                })
            else { continue }
            out[key] = title.key
        }
        return out
    }

    @Test func theCrossReferenceIsDiscovered() throws {
        let links = try Self.links()
        // Not a floor for its own sake: if the derivation stops
        // finding the one link that exists, every per-locale
        // assertion below passes over an empty set.
        #expect(
            links["behavior.animations.scrolling_xref_link"]
                == "sidebar.layout"
        )
    }

    @Test func everyLinkNamesItsDestinationAsShown() throws {
        let links = try Self.links()
        let titles = try SourceScan.sidebarTitles(
            root: Self.repoRoot
        )
        let english = try Self.catalog("en")
        let locales = try Self.shippedLocales()
        #expect(locales.count > 1)
        var checked = 0
        for locale in locales {
            let catalog = try Self.catalog(locale)
            for (linkKey, titleKey) in links {
                // NEITHER side is skipped when absent. Both fall
                // back to English per-key at runtime, so what
                // reaches the screen is a mismatch between what
                // each side RESOLVES to: a locale that
                // translates the label and drops the link
                // renders an English breadcrumb over a
                // translated row. `drop-key --locale` produces
                // exactly that state, so skipping the missing
                // side would fail open on a documented workflow.
                let link = catalog[linkKey] ?? english[linkKey]
                let shown =
                    catalog[titleKey]
                    ?? titles.first { $0.key == titleKey }?
                    .english
                guard let link else { continue }
                checked += 1
                #expect(
                    link.components(separatedBy: Self.separator)
                        .first == shown,
                    """
                    \(locale) \(linkKey) "\(link)" names a \
                    destination the sidebar shows as \
                    "\(shown ?? "—")" — a breadcrumb has to \
                    name the label on screen
                    """
                )
            }
        }
        // Derived: every locale is examined for every discovered
        // link, because neither side may be skipped. A shortfall
        // means the English fallback went missing too, which is
        // `en.json` being stale rather than a clean locale.
        #expect(checked == locales.count * links.count)
    }
}
