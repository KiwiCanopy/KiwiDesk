import Foundation
import Testing

@testable import KiwiDeskCore

/// The textual half of the Liquid Glass crossing (#1369), split
/// from `GlassDefaultMigrationTests` (tests.md ▸ split early): when
/// the surgical edit is taken, what it keeps, and every shape on
/// which it stands down to the walk — each read off the returned
/// TEXT, since a duplicate key collapses on re-parse and only the
/// bytes on disk can show it.
@Suite("Liquid Glass default migration — the textual edit (#1369)")
struct GlassDefaultMigrationEditTests {
    private func json(_ text: String) -> Data { Data(text.utf8) }

    /// The crossing as far as this step: the gate, the fill and
    /// the stamp. Since #1517 a later step moves the bars' leaves
    /// onto the shelf, so the full chain no longer shows the
    /// leaves this suite asserts on — `KiwiShelfMigrationTests`
    /// holds where they go.
    private func migratedThroughGlass(_ data: Data) -> Data? {
        guard ConfigMigration.needsMigration(data) else {
            return nil
        }
        let filled =
            ConfigMigration.migratingAbsentGlassLeaves(data) ?? data
        let out = ConfigMigration.stamped(filled)
        return out == data ? nil : out
    }

    private func profile(_ settings: String, format: Int = 3)
        -> Data
    {
        json(
            """
            {"format":\(format),"monitor_sets":{},\
            "settings":\(settings)}
            """
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    private func settings(_ data: Data) throws -> [String: Any] {
        try #require(root(data)["settings"] as? [String: Any])
    }

    private func leaf(
        _ settings: [String: Any],
        _ group: String
    ) -> Bool? {
        (settings[group] as? [String: Any])?["liquid_glass"]
            as? Bool
    }

    private func inline(_ name: String, settings: String) -> String {
        """
        {"format":3,"name":"\(name)","monitor_sets":[],\
        "settings":\(settings)}
        """
    }

    private func spellings(_ data: Data, of key: String) throws -> Int {
        let text = try #require(String(data: data, encoding: .utf8))
        return text.components(separatedBy: "\"\(key)\"").count - 1
    }

    /// The textual edit's stand-down: bars that disagree carry
    /// two values, so the edit stands down and the walk writes the
    /// file — pretty-printed, which is the walk's own signature on
    /// a profile root (a bundle is re-serialized at the stamp
    /// regardless, so it cannot show this).
    @Test("a shape the textual edit cannot take falls to the walk")
    func strayEditFallsToTheWalk() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":true},\
            "space_bar":{"liquid_glass":false,"thickness":20}}
            """
        )
        let out = try #require(migratedThroughGlass(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\n"))
        #expect(leaf(try settings(out), "shortcut_panel") == false)
    }

    /// The common shape takes the surgical edit: one line stays
    /// one line, and the user's own Doubles keep their spelling.
    @Test("the app-written shape keeps its formatting")
    func surgicalEditKeepsFormatting() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":false,"dim_factor":0.4},\
            "space_bar":{"liquid_glass":false}}
            """
        )
        let out = try #require(migratedThroughGlass(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\n"))
        #expect(!text.contains("0.40000000000000002"))
        #expect(leaf(try settings(out), "shortcut_panel") == false)
    }

    /// A glass-on profile the app wrote takes the surgical edit
    /// too: the panel is carried textually as the bars' value.
    @Test("a glass-on app-written profile keeps its formatting")
    func glassOnKeepsFormatting() throws {
        let data = profile(
            """
            {"app_bar":{"liquid_glass":true,"dim_factor":0.4},\
            "space_bar":{"liquid_glass":true}}
            """
        )
        let out = try #require(migratedThroughGlass(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\n"))
        #expect(leaf(try settings(out), "shortcut_panel") == true)
    }

    /// A nested object inside a bar group is a shape the leaf
    /// scan cannot read past; the edit stands down and the walk
    /// writes the leaf once.
    @Test("a nested object in a bar group stands the edit down")
    func nestedObjectStandsTheEditDown() throws {
        let data = profile(
            """
            {"app_bar":{"x":{"a":1},"liquid_glass":false},\
            "space_bar":{"liquid_glass":false}}
            """
        )
        let out = try #require(migratedThroughGlass(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(
            text.components(separatedBy: "\"liquid_glass\"").count
                == 4
        )
        #expect(leaf(try settings(out), "app_bar") == false)
    }

    /// An empty `settings` takes the three groups exactly once —
    /// the one opener is edited in one pass, and the text shows
    /// it where a re-parse would collapse a duplicate.
    @Test("an empty settings object takes each group once")
    func emptySettingsTakesEachGroupOnce() throws {
        let out = try #require(
            migratedThroughGlass(profile("{}"))
        )
        for group in ["app_bar", "space_bar", "shortcut_panel"] {
            #expect(try spellings(out, of: group) == 1)
        }
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\n"))
        #expect(leaf(try settings(out), "shortcut_panel") == false)
    }

    /// A missing bar leaf beside a glass-on bar is a disagreement
    /// the edit cannot carry: it stands down and the walk writes
    /// the panel off.
    @Test("a missing bar leaf beside glass on stands the edit down")
    func missingLeafBesideOnStandsDown() throws {
        let out = try #require(
            migratedThroughGlass(
                profile(
                    """
                    {"app_bar":{"liquid_glass":true},\
                    "space_bar":{"thickness":20}}
                    """
                )
            )
        )
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\n"))
        let s = try settings(out)
        #expect(leaf(s, "space_bar") == false)
        #expect(leaf(s, "shortcut_panel") == false)
    }

    /// A string value holding a brace is a body the scan cannot
    /// bound; the group no longer parses on its own, the edit
    /// stands down, and the leaf is spelled once.
    @Test("a brace inside a string stands the edit down")
    func braceInStringStandsDown() throws {
        let out = try #require(
            migratedThroughGlass(
                profile(
                    """
                    {"app_bar":{"item_color":"#a}b","liquid_glass":false},\
                    "space_bar":{"liquid_glass":false}}
                    """
                )
            )
        )
        #expect(try spellings(out, of: "liquid_glass") == 3)
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("\n"))
    }

    /// Two empty `settings` openers in one bundle, one value: the
    /// pass edits both, back to front, and each group is spelled
    /// once per profile. Asked of the edit directly, because a
    /// bundle is re-serialized at the format stamp after this
    /// step, so its bytes on disk cannot show the pass.
    @Test("two openers are each edited once")
    func twoOpenersAreEachEditedOnce() throws {
        let text =
            #"{"format":5,"writtenBy":"1.2.2","config":null,"#
            + #""profiles":[{"format":3,"settings":{}},"#
            + #"{"format":3,"settings":{}}],"palettes":[]}"#
        let edited = try #require(
            ConfigMigration.surgicallyFilledGlassLeaves(text)
        )
        let out = try #require(String(data: edited, encoding: .utf8))
        #expect(
            (try? JSONSerialization.jsonObject(with: edited)) != nil
        )
        for group in ["app_bar", "space_bar", "shortcut_panel"] {
            #expect(
                out.components(separatedBy: "\"\(group)\"").count - 1
                    == 2
            )
        }
    }

    /// An empty bar group takes its leaf without a trailing comma,
    /// which Foundation's parser would have tolerated on disk.
    @Test("an empty bar group takes the leaf without a comma")
    func emptyGroupTakesNoComma() throws {
        let out = try #require(
            migratedThroughGlass(
                profile(
                    #"{"app_bar":{},"space_bar":{"liquid_glass":false}}"#
                )
            )
        )
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("\n"))
        #expect(!text.contains(",}"))
        #expect(text.contains(#""app_bar":{"liquid_glass":false}"#))
    }

    /// The stand-downs, asked of the edit DIRECTLY: end to end the
    /// envelope's re-parse hides a refused edit behind the walk's
    /// identical bytes (guard-prover, 2026-09-13), so only this
    /// seam can show that the edit never computed one.
    @Test("the edit stands down on two values, a nest, or a panel")
    func editStandsDownDirectly() {
        let two =
            #"{"settings":{"app_bar":{"liquid_glass":true},"#
            + #""space_bar":{"liquid_glass":false}}}"#
        #expect(ConfigMigration.surgicallyFilledGlassLeaves(two) == nil)
        let nest =
            #"{"settings":{"app_bar":{"x":{"a":1}},"#
            + #""space_bar":{"liquid_glass":false}}}"#
        #expect(ConfigMigration.surgicallyFilledGlassLeaves(nest) == nil)
        let panel = #"{"settings":{"shortcut_panel":{}}}"#
        #expect(
            ConfigMigration.surgicallyFilledGlassLeaves(panel) == nil
        )
        let missing =
            #"{"settings":{"app_bar":{"liquid_glass":true},"#
            + #""space_bar":{"thickness":20}}}"#
        #expect(
            ConfigMigration.surgicallyFilledGlassLeaves(missing) == nil
        )
        let on =
            #"{"settings":{"app_bar":{"liquid_glass":true},"#
            + #""space_bar":{"liquid_glass":true}}}"#
        let edited = ConfigMigration.surgicallyFilledGlassLeaves(on)
            .flatMap { String(data: $0, encoding: .utf8) }
        let panelOn = #""shortcut_panel":{"liquid_glass":true}"#
        #expect(edited?.contains(panelOn) == true)
    }
}
