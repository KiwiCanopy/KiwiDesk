import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests for `ManagedConfig`'s split/merge logic and the
/// token-scoped foreign-code detection introduced in #14.
/// Round-trip and KiwiCore tests live in `ConfigWriteTests`.
@Suite("ManagedConfig split / detection")
struct ManagedConfigTests {
    // MARK: - Split & merge

    @Test("managed block splits and preserves user code")
    func managedSplit() {
        let source = """
            -- my own comment
            KiwiDesk.debug_log("hi")

            \(ManagedConfig.beginMarker)
            KiwiDesk.set_gap_global(10)
            \(ManagedConfig.endMarker)

            KiwiDesk.debug_log("after")
            """
        let split = ManagedConfig.split(source)
        #expect(split.managed?.contains("set_gap_global") == true)
        #expect(split.before.contains("my own comment"))
        #expect(split.after.contains("after"))
        // debug_log is NOT managed vocabulary: the visual editor
        // stays active; hasForeignCode must be false (#14).
        #expect(!ManagedConfig.hasForeignCode(source))
        // But there IS non-comment Lua outside the block.
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("comment-only files are neither foreign nor custom")
    func noForeignCode() {
        let source = """
            -- just a comment
            \(ManagedConfig.beginMarker)
            KiwiDesk.set_gap_global(10)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(!ManagedConfig.hasCustomCode(source))
    }

    @Test("merge replaces the block, keeps the surroundings")
    func mergeReplaces() {
        let original = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(10)",
            into: "-- header\n"
        )
        let updated = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(20)",
            into: original
        )
        #expect(updated.contains("set_gap_global(20)"))
        #expect(!updated.contains("set_gap_global(10)"))
        #expect(updated.contains("-- header"))
    }

    @Test("merge tolerates CRLF and keeps one block")
    func crlfMerge() {
        let source =
            "-- header\r\n" + ManagedConfig.beginMarker
            + "\r\nKiwiDesk.set_gap_global(10)\r\n"
            + ManagedConfig.endMarker + "\r\n"
        #expect(ManagedConfig.split(source).managed != nil)
        let merged = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(20)",
            into: source
        )
        let begins =
            merged.components(
                separatedBy: ManagedConfig.beginMarker
            ).count - 1
        #expect(begins == 1)
        #expect(merged.contains("set_gap_global(20)"))
        #expect(!merged.contains("set_gap_global(10)"))
    }

    @Test("merge strips an orphaned begin marker")
    func orphanMarker() {
        let source =
            "-- header\n" + ManagedConfig.beginMarker
            + "\nKiwiDesk.set_gap_global(10)\n"
        let merged = ManagedConfig.merge(
            block: "KiwiDesk.set_gap_global(20)",
            into: source
        )
        let begins =
            merged.components(
                separatedBy: ManagedConfig.beginMarker
            ).count - 1
        #expect(begins == 1)
        #expect(merged.contains("-- header"))
    }

    // MARK: - Token-scoped detection (#14)

    @Test("harmless custom Lua: not foreign, is custom")
    func harmlessCustomCode() {
        // Calls like debug_log, print, or sketchybar hooks
        // do not touch managed vocabulary → visual editor stays.
        let source = """
            KiwiDesk.debug_log("started")
            print("sketchybar hook")

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("managed-vocabulary Lua outside block is foreign")
    func managedVocabIsForeign() {
        // A binding outside the block touches KiwiDesk.bind(,
        // which the GUI writes inside the block → raw editor.
        let source = """
            KiwiDesk.bind("alt+h", function()
                KiwiDesk.focus("left")
            end)

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("app_rules outside the block is foreign")
    func appRulesIsForeign() {
        let source = """
            app_rules = { ["Finder"] = "1" }

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("float_rules outside the block is foreign")
    func floatRulesIsForeign() {
        let source = """
            float_rules = { "Calculator" }

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("define_mode outside the block is foreign")
    func defineModeIsForeign() {
        let source = """
            KiwiDesk.define_mode("resize", {})

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("bind_profile_to_native_space outside block is foreign")
    func profileBindingIsForeign() {
        let source = """
            KiwiDesk.bind_profile_to_native_space(1, "Desk")

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("tiling-only Lua beside the block is NOT foreign")
    func tilingOnlyIsNotForeign() {
        // set_gap_global, set_mode etc. are not in the managed
        // block (tiling moved to profiles, #36) — they're
        // harmless alongside the visual editor.
        let source = """
            KiwiDesk.set_gap_global(30)
            KiwiDesk.set_mode(1, "stack")

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("commented-out managed vocab is not foreign")
    func commentedManagedVocab() {
        // Comments are inert: a line that begins with -- is
        // skipped even if it contains a managed token.
        let source = """
            -- app_rules = { ["Finder"] = "1" }
            -- KiwiDesk.bind("x", function() end)

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(!ManagedConfig.hasCustomCode(source))
    }
}

// MARK: - Vocabulary parity test

/// Verifies that every top-level construct `LuaConfigWriter`
/// emits into a managed block is covered by at least one token
/// in `ManagedConfig.managedTokens`. If `LuaConfigWriter` gains
/// a new top-level construct without a matching token, this test
/// fails — preventing silent drift between the writer and the
/// detection logic.
@Suite("Managed-vocabulary parity")
struct ManagedVocabularyTests {
    /// A config that exercises all five managed-vocabulary
    /// constructs: app rules, float rules, profile bindings,
    /// a default-mode bind, and a named mode.
    private func vocabConfig() -> GuiConfig {
        var c = GuiConfig()
        c.appRules = ["Finder": SpaceID(1)]
        c.floatRules = ["Calculator"]
        c.profileBindings = [1: "Desk"]
        c.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "-- noop"
                    )
                ]
            ),
            KeyMode(
                name: "resize",
                bindings: [
                    KeyBinding(
                        combo: "alt+l",
                        lua: "-- noop"
                    )
                ]
            ),
        ]
        return c
    }

    @Test(
        "every managed token appears in a full block"
    )
    func tokensAppearInGeneratedBlock() {
        let block = LuaConfigWriter.block(for: vocabConfig())
        for token in ManagedConfig.managedTokens {
            #expect(
                block.contains(token),
                "token \"\(token)\" not found in generated block"
            )
        }
    }

    @Test(
        "every top-level writer line is covered by a token"
    )
    func writerLinesAreCovered() {
        let block = LuaConfigWriter.block(for: vocabConfig())
        for line in block.components(separatedBy: "\n") {
            // Skip blank lines and full-line comments.
            let trimmed = line.trimmingCharacters(
                in: .whitespaces
            )
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix("--") else { continue }
            // Skip indented lines (table entries, bodies).
            guard
                line.first != " ", line.first != "\t"
            else { continue }
            // Skip structural closing tokens.
            guard
                !trimmed.hasPrefix("}"),
                !trimmed.hasPrefix("end")
            else { continue }
            let covered = ManagedConfig.managedTokens
                .contains { trimmed.contains($0) }
            #expect(
                covered,
                "unrecognized top-level line: \"\(trimmed)\""
            )
        }
    }
}
