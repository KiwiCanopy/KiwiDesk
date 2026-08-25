import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests for `ManagedConfig`'s token-scoped foreign-code detection
/// (#14). #55: the app no longer generates a managed block, and
/// #116 removed the marker-block recognition entirely — `classify`
/// now scans the whole source. Round-trip and KiwiCore tests live
/// in `ConfigWriteTests`.
@Suite("ManagedConfig detection")
struct ManagedConfigTests {
    // MARK: - Token-scoped detection (#14)

    @Test("harmless custom Lua: not foreign, is custom")
    func harmlessCustomCode() {
        // Calls like debug_log, print, or sketchybar hooks
        // do not touch managed vocabulary → visual editor stays.
        let source = """
            KiwiDesk.debug_log("started")
            print("sketchybar hook")
            """
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("comment-only files are neither foreign nor custom")
    func commentOnly() {
        let source = "-- just a comment\n-- and another"
        #expect(!ManagedConfig.hasForeignCode(source))
        #expect(!ManagedConfig.hasCustomCode(source))
    }

    @Test("managed-vocabulary Lua is foreign")
    func managedVocabIsForeign() {
        // A binding touches KiwiDesk.bind(, which the GUI owns in
        // gui.json → raw editor.
        let source = """
            KiwiDesk.bind("alt+h", function()
                KiwiDesk.focus("left")
            end)
            """
        #expect(ManagedConfig.hasForeignCode(source))
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("app_rules is foreign")
    func appRulesIsForeign() {
        let source = #"app_rules = { ["Finder"] = "1" }"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("float_rules is foreign")
    func floatRulesIsForeign() {
        let source = #"float_rules = { "Calculator" }"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("ignore_rules is foreign")
    func ignoreRulesIsForeign() {
        let source = #"ignore_rules = { "io.tailscale.ipn.macos" }"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("define_layer is foreign")
    func defineModeIsForeign() {
        let source = #"KiwiDesk.define_layer("resize", {})"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("bind_profile_to_desktop is foreign")
    func profileBindingIsForeign() {
        let source =
            #"KiwiDesk.bind_profile_to_desktop(1, "Desk")"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("tiling-only Lua is NOT foreign")
    func tilingOnlyIsNotForeign() {
        // set_gap_global, set_mode etc. are not foreign tokens
        // (tiling moved to profiles, #36) — harmless alongside the
        // visual editor, though a `set_*` verb still declares a
        // managed setting (see `declaresManagedSettingsTests`).
        let source = """
            KiwiDesk.set_gap_global(30)
            KiwiDesk.set_mode(1, "stack")
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
            """
        #expect(ManagedConfig.hasForeignCode(source))
    }

    @Test("KiwiDesk.define_layer with space before ( is foreign")
    func defineModeWithSpaceBeforeParenIsForeign() {
        let source = #"KiwiDesk.define_layer ("resize", {})"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    // MARK: - Substring anchoring for bare identifiers (Fix 4)

    @Test("app_rules inside longer identifier is not foreign")
    func appRulesSubstringNotForeign() {
        // app_rules_count contains app_rules but is a
        // different identifier: the word-boundary + assignment
        // anchor prevents a false positive.
        let source = "local app_rules_count = 0"
        #expect(!ManagedConfig.hasForeignCode(source))
        // It IS custom (a non-comment Lua line).
        #expect(ManagedConfig.hasCustomCode(source))
    }

    @Test("app_rules inside a string literal is not foreign")
    func appRulesInStringNotForeign() {
        // A string literal containing the token word must
        // not be detected as foreign (no assignment).
        let source = #"print("app_rules")"#
        #expect(!ManagedConfig.hasForeignCode(source))
    }

    @Test("app_rules assignment is foreign")
    func appRulesAssignmentForeign() {
        let source = #"app_rules = { ["Finder"] = "1" }"#
        #expect(ManagedConfig.hasForeignCode(source))
    }

    // MARK: - Block-comment behavior (Fix 5 — pinned)

    @Test("block-comment interior lines are treated as code")
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
            """
        // Over-conservative: interior is seen as code.
        #expect(ManagedConfig.hasCustomCode(source))
        // No managed vocabulary → not foreign.
        #expect(!ManagedConfig.hasForeignCode(source))
    }
}
