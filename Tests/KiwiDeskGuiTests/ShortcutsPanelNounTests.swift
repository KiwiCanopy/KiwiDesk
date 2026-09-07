import Foundation
import Testing

/// The ⌃⌥K surface has ONE name per catalog: whatever a locale
/// calls the panel when it points AT it, the panel's own
/// accessibility name uses (#1316,
/// `.claude/rules/config-vocabulary.md` ▸ shortcuts panel).
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
/// What it does NOT cover, so a green run is not read as more:
/// containment is the whole predicate, so a locale that
/// INFLECTS the noun inside the verb phrase — a case-marking
/// language whose accusative differs from the citation form —
/// reds here correctly rather than falsely, and takes an
/// `allowed` entry stating the two forms. Every shipped catalog
/// today keeps the citation form, which is why the map is empty.
@Suite("The shortcuts panel has one name per catalog")
struct ShortcutsPanelNounTests {
    /// The panel's own accessibility name.
    static let panelName = "shortcuts.panel.ax_label"
    /// The verb that opens it, which names it in passing.
    static let opener = "keybinding.show_shortcuts"

    /// Locales whose grammar inflects the noun inside the verb
    /// phrase, each naming the two forms — **the one copy of who
    /// may**. EMPTY: nothing shipped inflects it today.
    static let allowed: [String: String] = [:]

    @Test("the panel's own name is the noun its opener uses")
    func oneNounPerCatalog() throws {
        for locale in try Self.catalogNames() {
            let catalog = try Self.catalog(locale)
            guard let name = catalog[Self.panelName],
                let opens = catalog[Self.opener]
            else { continue }
            guard Self.allowed[locale] == nil else { continue }
            #expect(
                opens.lowercased().contains(name.lowercased()),
                """
                \(locale): the panel announces itself as \
                "\(name)" while the shortcut that opens it says \
                "\(opens)" — two names for one surface (#1316). \
                Give the panel the noun the opener already uses, \
                or add \(locale) to `allowed` naming the two \
                grammatical forms.
                """
            )
        }
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
