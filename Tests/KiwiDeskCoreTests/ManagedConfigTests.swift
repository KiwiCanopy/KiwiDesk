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

    // MARK: - Whitespace-before-paren (Fix 1)

    @Test("KiwiDesk.bind with space before ( is foreign")
    func bindWithSpaceBeforeParenIsForeign() {
        // A space between the method name and ( must not
        // escape token detection (#14 fix: whitespace is
        // normalized before matching).
        let source = """
            KiwiDesk.bind ("alt+h", function()
                KiwiDesk.focus("left")
            end)

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("KiwiDesk.define_mode with space before ( is foreign")
    func defineModeWithSpaceBeforeParenIsForeign() {
        let source = """
            KiwiDesk.define_mode ("resize", {})

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    // MARK: - Substring anchoring for bare identifiers (Fix 4)

    @Test("app_rules inside longer identifier is not foreign")
    func appRulesSubstringNotForeign() {
        // app_rules_count contains app_rules but is a
        // different identifier: the word-boundary + assignment
        // anchor prevents a false positive.
        let source = """
            local app_rules_count = 0

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
        // It IS custom (a non-comment Lua line).
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("app_rules inside a string literal is not foreign")
    func appRulesInStringNotForeign() {
        // A string literal containing the token word must
        // not be detected as foreign (no assignment).
        let source = """
            print("app_rules")

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(!ManagedConfig.hasForeignCode(source))
    }

    @Test("app_rules assignment outside block is foreign")
    func appRulesAssignmentForeign() {
        let source = """
            app_rules = { ["Finder"] = "1" }

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    // MARK: - Block-comment behavior (Fix 5 — pinned)

    @Test(
        "block-comment interior lines are treated as code"
    )
    func blockCommentInteriorIsTreatedAsCode() {
        // --[[ … ]] block comments: interior lines that don't
        // start with -- are treated as code by the current
        // line-by-line scan (known limitation — see isCode).
        // This test pins the behavior so it is not mistaken
        // for handled.
        let source = """
            --[[ multi-line block comment
            this line has no leading dashes
            ]]

            \(ManagedConfig.beginMarker)
            \(ManagedConfig.endMarker)
            """
        // Over-conservative: interior is seen as code.
        #expect(ManagedConfig.hasCustomCode(source))
        // No managed vocabulary → not foreign.
        #expect(!ManagedConfig.hasForeignCode(source))
    }
}
