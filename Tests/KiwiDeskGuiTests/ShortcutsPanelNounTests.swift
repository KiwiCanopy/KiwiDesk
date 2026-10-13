import Foundation
import Testing

/// Each key panel has ONE name per catalog: whatever a locale
/// calls the panel when it points AT it, the panel's own
/// accessibility name uses (#1316,
/// `.claude/rules/config-vocabulary.md` ▸ shortcuts panel). The
/// pairing covers every panel a shortcut row shows: the ⌃⌥K
/// panel, and each side of the ⌃⌥J / ⌃⌥L panel, whose row reads
/// "Show" and that side's VoiceOver name (#2245,
/// `.claude/rules/gui.md` ▸ a row's title).
///
/// The defect this reds on is not inconsistency in the abstract.
/// `shortcuts.panel.ax_label` shipped as "Shortcuts reference"
/// while `keybinding.show_shortcuts` said "Show shortcuts panel",
/// so a sighted user read one noun and a VoiceOver user heard
/// another for one surface — and all ten catalogs faithfully
/// mirrored it, because a correct translation of a wrong source
/// looks exactly like this.
///
/// **Family C says no guard is possible; that is about a
/// content-guard predicate, and this is not one** — the argument
/// is `DestinationNameCollisionTests`', which holds the
/// exact-collision sub-class the same way, and is not repeated
/// here. This suite reads no vocabulary: it asks only whether
/// ONE catalog's two strings for one surface share a noun, by
/// containment.
///
/// **What it holds is containment, one-directional**, and the
/// docstring says so rather than claiming the whole invariant:
/// the panel's name must be SOME substring of the opener. Two
/// shapes therefore pass, both measured (`guard-prover`, #1316)
/// rather than reasoned about:
///
/// - a panel name SHORTENED to a bare head noun — `fr`
///   announcing `Raccourcis` against "Afficher le panneau des
///   raccourcis" is two names for one surface and stays green,
///   as does any substring down to one character;
/// - a second noun regrowing on the OPENER — "Show shortcuts
///   panel reference" contains the panel's name and passes.
///
/// Both need per-language vocabulary to tell from a legitimate
/// rewording, which is the register Family C rules a guard may
/// not carry. They stay with review. What is bought is the
/// shape that actually shipped: the two keys naming the surface
/// with DIFFERENT nouns.
///
/// A locale that INFLECTS the noun inside the verb phrase — a
/// case-marking language whose accusative differs from the
/// citation form — reds correctly rather than falsely, and takes
/// an `allowed` entry naming the form the opener carries, which
/// is then checked in the citation form's place. Every shipped
/// catalog today keeps the citation form, so the map is empty.
///
/// An empty value does NOT pass vacuously: `contains("")` is
/// false in Swift, so an untranslated-empty merge reds.
@Suite("Each key panel has one name per catalog")
struct ShortcutsPanelNounTests {
    /// A panel's own accessibility name, and the row that opens
    /// it, which names it in passing.
    struct Pair {
        let panelName: String
        let opener: String
    }

    /// Every panel a shortcut row opens.
    static let pairs = [
        Pair(
            panelName: "shortcuts.panel.ax_label",
            opener: "keybinding.show_shortcuts"
        ),
        Pair(
            panelName: "jump.panel.ax_label",
            opener: "keybinding.show_window_switcher"
        ),
        Pair(
            panelName: "layout_picker.panel.ax_label",
            opener: "keybinding.show_layout_picker"
        ),
    ]

    /// Panel names authored before their translation round, whose
    /// opener a catalog already carries — the one copy of who may
    /// be absent beside it. An entry reds once any translation
    /// carries the key, so the round must retire it (#2245).
    static let awaitingTranslation: Set<String> = [
        "layout_picker.panel.ax_label"
    ]

    /// Locales whose grammar inflects the noun inside the verb
    /// phrase, keyed by panel name and then locale, valued by the
    /// form the OPENER carries — **the one copy of who may**.
    ///
    /// The value is checked, not decoration: an entry narrows
    /// the comparison to that form rather than dropping the
    /// locale out of it, so an exemption still holds the pairing
    /// it was granted for. EMPTY: nothing shipped inflects it.
    static let allowed: [String: [String: String]] = [:]

    @Test(
        "the panel's own name is the noun its opener uses",
        arguments: pairs.map(\.panelName)
    )
    func oneNounPerCatalog(panelName: String) throws {
        let pair = try #require(
            Self.pairs.first { $0.panelName == panelName }
        )
        var compared = 0
        for locale in try Self.catalogNames() {
            let catalog = try Self.catalog(locale)
            let name = catalog[pair.panelName]
            let opens = catalog[pair.opener]
            if Self.awaitingTranslation.contains(pair.panelName) {
                if locale != "en", name != nil {
                    Issue.record(
                        """
                        \(locale) translates \(pair.panelName), so \
                        its round has come: remove it from \
                        `awaitingTranslation`.
                        """
                    )
                }
                if locale != "en", name == nil { continue }
            }
            // ONE of the two present is the defect wearing the
            // English fallback: `drop-key --locale` retires a bad
            // translation, after which that locale announces the
            // English noun against its own translated opener.
            // Skipping it is how the guard would go quiet on the
            // exact repair path (`guard-prover`, #1316).
            if (name == nil) != (opens == nil) {
                Issue.record(
                    """
                    \(locale) carries one of \(pair.panelName) / \
                    \(pair.opener) and not the other, so the \
                    surface is named by a translation on one \
                    channel and by the English fallback on the \
                    other — the #1316 split, wearing a fallback.
                    """
                )
                continue
            }
            guard let name, let opens else { continue }
            compared += 1
            let expected = Self.allowed[pair.panelName]?[locale] ?? name
            #expect(
                opens.lowercased().contains(expected.lowercased()),
                """
                \(locale): the panel announces itself as \
                "\(name)" while the shortcut that opens it says \
                "\(opens)" — two names for one surface (#1316). \
                Give the panel the noun the opener already uses, \
                or add \(locale) to `allowed` naming the form \
                the opener carries.
                """
            )
        }
        // The floor counts COMPARISONS, never files: every
        // catalog losing the key passes a file count and
        // compares nothing (`guard-prover`, #1316). A pair before
        // its translation round compares English alone.
        #expect(
            compared >= 1,
            """
            \(compared) catalog(s) actually compared — this \
            suite passed for having looked at nothing.
            """
        )
    }

    /// English lives at the call sites and is regenerated into
    /// `en.json`, so it is checked here beside the translations
    /// — it is the source the split came from.
    private static func catalogNames() throws -> [String] {
        let names = try FileManager.default
            .contentsOfDirectory(atPath: localesDirectory.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
        for name in names where name.hasPrefix("missing_") {
            Issue.record(
                """
                \(name) is a translator worksheet sitting in the \
                catalog directory. It belongs under \
                locale-worksheets/ — every reader of this \
                directory globs *.json and will try to decode it.
                """
            )
        }
        let shipped =
            names
            .filter { !$0.hasPrefix("missing_") }
            .map { String($0.dropLast(".json".count)) }
        #expect(
            shipped.count > 1,
            "the catalog directory yielded nothing to compare"
        )
        return shipped
    }

    private static var localesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
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
}
