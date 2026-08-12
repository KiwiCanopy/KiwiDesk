import Foundation
import Testing

/// A destination's name must not be, in any catalog, the string
/// some OTHER feature ships — `docs/localization-naming.md`
/// ▸ Family C, ladder rule 1, the rung nothing outranks.
///
/// This is the sub-class that hurts most, because the label does
/// not read as merely inconsistent: it reads as **true about the
/// wrong thing**. `zh-Hans` rendered `destination.profiles` as
/// 配置文件, byte-identical to what `general.advanced.config_file`
/// ships, so searching for a profile by name returned a result
/// whose kind line said *configuration file* (#807). A
/// destination title is the worst place for it — the same string
/// is a card title, a back-chip heading and a search kind-line at
/// once, so one collision surfaces on every hit inside that pane.
///
/// **Family C says no guard is possible; that claim is about a
/// content-guard predicate and this is not one.** A banned-rival
/// word register inside `scripts/localization_guards.py` genuinely
/// cannot work — every losing word is legitimately correct
/// elsewhere in the same file, so it would fire on hundreds of
/// good values, and that script has no exemption file by policy.
/// This suite reads no vocabulary at all. It compares two strings
/// the SAME catalog ships, the way `SidebarCrossReferenceTests`
/// does, and a `Tests/` suite may carry a reasoned `allowed` map
/// — which is the standing idiom for a dozen AGENTS.md §5 rows.
/// So the two coexist: the script cannot hold this, and this
/// holds only the sub-class it can prove.
///
/// What it therefore does NOT cover, stated so a green run is not
/// read as more: only EXACT equality, and only against a
/// destination. `es` labelling a bar gap "Espacio" against a
/// Space of "Espacios" is the same defect class and is invisible
/// here — near-equality cannot be judged without per-language
/// morphology, which is the vocabulary this suite refuses to
/// carry. That half stays with review, and Family C's ladder is
/// what makes that review a grep.
@Suite("Destination names collide with no other feature")
struct DestinationNameCollisionTests {
    /// Pairs that may render identically, each with the reason.
    /// Keyed by the destination key, valued by the keys it is
    /// allowed to equal — **the one copy of who may**.
    ///
    /// An entry earns its place by the two ENGLISH strings naming
    /// one thing, so a locale collapsing them is correct rather
    /// than colliding. That is a different test from "the English
    /// differs", which is what the scan below applies: `Shortcuts`
    /// and `Your shortcuts` are one concept wearing a possessive,
    /// and `ja`/`ko` rightly drop it.
    static let allowed: [String: Set<String>] = [
        // The onboarding step's heading and the destination name
        // the same pane; English differs only by the possessive,
        // which several languages do not use in a heading.
        "destination.shortcuts": ["onboarding.keys.title"]
    ]

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

    /// Enumerates locale CODES and decodes none of them — the one
    /// shape allowed to filter `missing_` by name (#692), so a
    /// stray worksheet cannot be mis-reported as a shipped locale
    /// before `extract-keys --check` has rejected it.
    private static func shippedLocales() throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(atPath: localesDirectory.path)
            .filter { $0.hasSuffix(".json") }
            .filter { !$0.hasPrefix("missing_") }
            .map { String($0.dropLast(".json".count)) }
            .filter { $0 != "en" }
            .sorted()
    }

    /// Two English strings name one thing when they differ only
    /// by case, surrounding space or a trailing plural `s`. Kept
    /// deliberately crude: it exists to stop the scan reporting
    /// `Spaces` ≡ `Space` as a collision, not to judge synonymy —
    /// anything subtler is the `allowed` map's job, where it has
    /// to be argued in writing.
    private static func sameThing(_ a: String, _ b: String) -> Bool {
        func stem(_ s: String) -> String {
            let trimmed = s.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()
            return trimmed.hasSuffix("s")
                ? String(trimmed.dropLast()) : trimmed
        }
        return stem(a) == stem(b)
    }

    /// The destination keys, DERIVED from `en.json` rather than
    /// listed, so a destination added later is covered the day it
    /// lands.
    private static func destinationKeys() throws -> [String] {
        try catalog("en").keys
            .filter { $0.hasPrefix("destination.") }
            .sorted()
    }

    /// An empty scan passes for having found nothing, which is
    /// the failure `rule-authoring.md` names — so assert the
    /// inputs before asserting anything about them.
    @Test("the scan has destinations and catalogs to compare")
    func inputsAreNotEmpty() throws {
        let destinations = try Self.destinationKeys()
        #expect(
            destinations.count >= 10,
            """
            found \(destinations.count) destination key(s) in \
            en.json — the prefix moved and this suite is \
            comparing nothing.
            """
        )
        let locales = try Self.shippedLocales()
        #expect(
            locales.count >= 10,
            "found \(locales.count) shipped locale(s)"
        )
    }

    @Test("no destination name is another feature's string")
    func destinationsAreUnique() throws {
        let english = try Self.catalog("en")
        let destinations = try Self.destinationKeys()
        for locale in try Self.shippedLocales() {
            let catalog = try Self.catalog(locale)
            for destination in destinations {
                guard let name = catalog[destination] else {
                    continue
                }
                let permitted =
                    Self.allowed[destination] ?? []
                for (key, value) in catalog
                where key != destination && value == name {
                    guard !permitted.contains(key) else {
                        continue
                    }
                    // Two keys whose ENGLISH names one thing are
                    // right to render alike; only a genuine
                    // second referent is a collision.
                    guard
                        !Self.sameThing(
                            english[key] ?? "",
                            english[destination] ?? ""
                        )
                    else { continue }
                    let ours =
                        english[destination]?.debugDescription
                        ?? "?"
                    let theirs =
                        english[key]?.debugDescription ?? "?"
                    Issue.record(
                        """
                        \(locale).json :: \(destination) renders \
                        \(name.debugDescription), which is also \
                        what \(key) ships — but their English \
                        differs (\(ours) vs \(theirs)). One of \
                        the two names the wrong feature. Pick a \
                        distinct word per \
                        docs/localization-naming.md ▸ Family C, \
                        ladder rule 1 — or, if the two English \
                        strings really do name one thing, add \
                        the pair to `allowed` with that reason.
                        """
                    )
                }
            }
        }
    }

    /// Every `allowed` entry still names keys that exist, so an
    /// exemption cannot outlive the pair it excuses — the
    /// stale-exemption failure `SettingsBorderedSealTests` also
    /// guards against.
    @Test("every allowed pair still exists")
    func allowedPairsResolve() throws {
        let english = try Self.catalog("en")
        for (destination, twins) in Self.allowed {
            #expect(
                english[destination] != nil,
                "allowed names \(destination), not in en.json"
            )
            for twin in twins {
                #expect(
                    english[twin] != nil,
                    "allowed names \(twin), not in en.json"
                )
            }
        }
    }
}
