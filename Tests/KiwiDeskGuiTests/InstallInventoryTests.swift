import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// About's "what this install holds" counts (#795, re-scoped).
///
/// **Asserted as arithmetic.** A row that renders a plausible
/// constant satisfies every source needle, which is the failure
/// this tree has already paid for once — so the counts are read
/// directly off a model built here.
@Suite("Install inventory")
@MainActor
struct InstallInventoryTests {
    private func inventory(
        profiles: [String] = [],
        spaces: [SpaceID] = [],
        appRules: [String: SpaceID] = [:],
        layers: [KeyLayer]? = nil
    ) -> InstallInventory {
        let model = makeTestModel()
        model.profiles = profiles
        model.config.spaces = spaces
        model.config.appRules = appRules
        if let layers { model.config.layers = layers }
        return InstallInventory(model: model)
    }

    private func binding(_ combo: String) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            label: combo
        )
    }

    /// Each count reads its own source — a row wired to the
    /// wrong collection is invisible on screen (four plausible
    /// numbers) and is exactly what this pins.
    @Test("each row counts its own thing")
    func rowsCountTheirOwnSource() {
        var layer = KeyLayer.defaultLayer
        layer.bindings = [binding("control+option+1")]
        let view = inventory(
            profiles: ["work", "home", "travel"],
            spaces: ["1", "2"],
            appRules: ["Safari": "1", "Mail": "2", "Code": "1"],
            layers: [layer]
        )
        let counts = view.rows.map(\.count)
        #expect(counts == [3, 2, 1, 3])
    }

    /// Shortcuts are counted across EVERY layer, not the default
    /// one alone: a layer is an alternate set, and a chord bound
    /// only in one still exists. Counting the first layer would
    /// read plausibly and undercount every user who has one.
    @Test("shortcuts count every layer")
    func shortcutsSpanLayers() {
        var base = KeyLayer.defaultLayer
        base.bindings = [
            binding("control+option+1"),
            binding("control+option+2"),
        ]
        var alt = KeyLayer.defaultLayer
        alt.bindings = [binding("control+option+3")]
        let view = inventory(layers: [base, alt])
        #expect(view.rows[2].count == 3)
    }

    /// An empty install reports zeroes rather than hiding rows:
    /// the block answers "what is in here", and a missing row
    /// cannot be told from a row that has not loaded.
    @Test("an empty install still states its zeroes")
    func emptyInstallShowsZeroes() {
        var layer = KeyLayer.defaultLayer
        layer.bindings = []
        let view = inventory(layers: [layer])
        #expect(view.rows.count == 4)
        #expect(view.rows.allSatisfy { $0.count == 0 })
    }

    /// Every frame puts its number LAST behind a label, so no
    /// locale has to agree with a count mid-sentence
    /// (`localization.md`).
    ///
    /// Read from the shipped `en.json` rather than from a
    /// rendered row: the `L(key, english, args…)` overload
    /// substitutes the count at render time, so the drawn string
    /// no longer contains a specifier to inspect. The English in
    /// the catalog is what translators mirror, which makes it
    /// the thing worth holding.
    ///
    /// This clause is also WHY the counts are rows rather than
    /// the issue's one-sentence "3 profiles, 6 Spaces, 18
    /// shortcuts, 3 app rules" — four counts cannot each be
    /// last, so the localization rule forced the shape.
    @Test("every count sits last in its English frame")
    func countsComeLast() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales/en.json"
            )
        let data = try Data(contentsOf: root)
        let catalog =
            try JSONSerialization.jsonObject(with: data)
            as? [String: String]
        let english = try #require(catalog)
        // DERIVED from the rows, not hand-listed: a fifth
        // inventory row is then covered by existing, which a
        // four-key literal is not (`parity-tests.md` — prefer a
        // discovered list; re-review, 2026-08-16).
        let keys = inventory().rows.map {
            "general.inventory.\($0.id)"
        }
        #expect(!keys.isEmpty)
        for key in keys {
            let frame = try #require(
                english[key],
                Comment(rawValue: "\(key) is not in en.json")
            )
            #expect(
                frame.hasSuffix("%1$d"),
                Comment(
                    rawValue:
                        "\(key) — \"\(frame)\" does not end in "
                        + "its count"
                )
            )
            #expect(
                frame.components(separatedBy: "%1$d").count == 2,
                Comment(
                    rawValue:
                        "\(key) spends its specifier more than "
                        + "once"
                )
            )
        }
    }
}
