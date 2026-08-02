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
/// Every segment is held, not just the head. The tail names a
/// layout mode, and the check needs no opinion about which
/// locales render mode names natively: the segment must equal
/// that locale's OWN `layout.<mode>.name`, whatever it says.
/// That is deliberately not the mode-name policy — which
/// `scripts/localization_guards.py` owns, and enforces in one
/// direction only (translated picker, English prose), leaving
/// the polarity that actually shipped here unreachable:
/// `zh-Hant`'s picker keeps the English "Scrolling" while its
/// breadcrumb said 捲動, so the guard skipped the locale by
/// construction and nothing else was looking.
///
/// A breadcrumb authored MID-SENTENCE is also outside the net:
/// its first segment is the prose before it, which matches no
/// title, so it never enters the derived set — `en.json`'s
/// `behavior.animations.master.help` is exactly that shape.
/// `theCrossReferenceIsDiscovered` pins the one link that
/// exists today; a second one written mid-sentence would be
/// dropped with nothing noticing.
///
/// The two sides also resolve through different authorities —
/// the link's English through `en.json`, the title's through
/// the source literal `SourceScan.sidebarTitles` reads. They
/// agree only because `extract-keys --check` pins `en.json` to
/// the call sites, and that runs in `scripts/lint.sh`, not
/// here. Benign, but the symmetry is one gate wide, not zero.
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

    /// A discovered breadcrumb: its English text, and the
    /// catalog key that owns each segment.
    struct Link {
        let english: String
        /// One entry per `▸` segment — the destination title key
        /// for the head, a `layout.<mode>.name` for a tail
        /// segment naming a mode, `nil` where no key owns it.
        let segmentKeys: [String?]
    }

    /// Every `▸` string whose English HEAD is a destination
    /// title, with each segment resolved to the key that owns
    /// it. Both halves are derived the same way — by matching
    /// the English against a set the app already ships — so the
    /// tail needs no policy opinion about which locales render
    /// a mode name natively: it simply has to agree with that
    /// locale's OWN `layout.<mode>.name`, whatever that says.
    private static func links() throws -> [String: Link] {
        let titles = try SourceScan.sidebarTitles(root: repoRoot)
        let english = try catalog("en")
        // English mode name → its key, so a tail segment can be
        // attributed to the picker entry it must match.
        var modeKeys: [String: String] = [:]
        for (key, value) in english
        where key.hasPrefix("layout.") && key.hasSuffix(".name") {
            modeKeys[value] = key
        }
        var out: [String: Link] = [:]
        for (key, value) in english {
            let segments = value.components(
                separatedBy: separator
            )
            guard
                segments.count > 1,
                let head = segments.first,
                let title = titles.first(where: {
                    $0.english == head
                })
            else { continue }
            out[key] = Link(
                english: value,
                segmentKeys: [title.key]
                    + segments.dropFirst().map { modeKeys[$0] }
            )
        }
        return out
    }

    /// A key's English: `en.json` for a catalog key, the scanned
    /// call-site literal for a destination title (which is where
    /// English actually lives for those).
    private static func englishFor(
        key: String,
        english: [String: String],
        titles: [SourceScan.SidebarTitle]
    ) -> String? {
        english[key]
            ?? titles.first { $0.key == key }?.english
    }

    @Test func theCrossReferenceIsDiscovered() throws {
        let links = try Self.links()
        // Not a floor for its own sake: if the derivation stops
        // finding the one link that exists, every per-locale
        // assertion below passes over an empty set. Both
        // segments must resolve — a tail that stops matching a
        // picker entry would otherwise silently go unwatched.
        let link = try #require(
            links["behavior.animations.scrolling_xref_link"]
        )
        #expect(
            link.segmentKeys == [
                "sidebar.layout", "layout.scrolling.name",
            ]
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
        var translated = 0
        for locale in locales {
            let catalog = try Self.catalog(locale)
            for (linkKey, link) in links {
                // NEITHER side is skipped when absent. Both fall
                // back to English per-key at runtime, so what
                // reaches the screen is a mismatch between what
                // each side RESOLVES to: a locale that
                // translates the label and drops the link
                // renders an English breadcrumb over a
                // translated row. `drop-key --locale` produces
                // exactly that state, so skipping the missing
                // side would fail open on a documented workflow.
                //
                // `link.english` rather than `english[linkKey]`:
                // the value came OUT of `en.json`, so an
                // optional here would be dead code the way the
                // retired count pin was.
                let shownLink = catalog[linkKey] ?? link.english
                if catalog[linkKey] != nil { translated += 1 }
                let segments = shownLink.components(
                    separatedBy: Self.separator
                )
                #expect(
                    segments.count == link.segmentKeys.count,
                    """
                    \(locale) \(linkKey) "\(shownLink)" has \
                    \(segments.count) segments, not \
                    \(link.segmentKeys.count)
                    """
                )
                for (segment, key) in zip(
                    segments,
                    link.segmentKeys
                ) {
                    // A segment no key owns is prose the
                    // translation may word freely.
                    guard let key else { continue }
                    let shown =
                        catalog[key]
                        ?? Self.englishFor(
                            key: key,
                            english: english,
                            titles: titles
                        )
                    #expect(
                        segment == shown,
                        """
                        \(locale) \(linkKey) "\(shownLink)" \
                        names \(key) as "\(segment)" — on \
                        screen that reads "\(shown ?? "—")"
                        """
                    )
                }
            }
        }
        // Counts what is actually TRANSLATED, not what was
        // examined. An examined-count pin would be inert here:
        // `links` is built out of `en.json`, so the English
        // fallback is non-nil by construction and every locale
        // is always examined — the number could not move. What
        // can move is coverage, and a corpus where no locale
        // translates the breadcrumb at all is one where every
        // comparison above is English against English and this
        // guard has stopped watching translations.
        #expect(translated > 0)
    }
}
