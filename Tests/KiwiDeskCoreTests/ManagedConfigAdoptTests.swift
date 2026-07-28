import Testing

@testable import KiwiDeskCore

/// `ManagedConfig.adopt` selective commenting (#355): managed
/// statements (settings, rules, keybindings now owned by
/// `gui.json`) are commented out; harmless custom Lua (hooks,
/// `print`, helpers) is kept live so integrations keep firing.
/// The load-bearing invariant — the adopted file is never foreign
/// — is asserted on every case, plus the structural fallback.
@Suite("ManagedConfig adopt keeps custom live")
struct ManagedConfigAdoptTests {
    private func adopt(_ source: String) -> String {
        ManagedConfig.adopt(original: source, date: "2026-07-18")
    }

    /// A line is live iff it appears (indentation-insensitive) and
    /// is not commented.
    private func isLive(
        _ needle: String,
        in adopted: String
    ) -> Bool {
        let want = needle.trimmingCharacters(in: .whitespaces)
        return adopted.components(separatedBy: "\n").contains {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return !t.hasPrefix("--") && t == want
        }
    }

    /// A line is commented iff a `--`-prefixed line carries it
    /// (indentation- and prefix-spacing-insensitive).
    private func isCommented(
        _ needle: String,
        in adopted: String
    ) -> Bool {
        let want = needle.trimmingCharacters(in: .whitespaces)
        return adopted.components(separatedBy: "\n").contains {
            let t = $0.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("--") else { return false }
            return t.dropFirst(2)
                .trimmingCharacters(in: .whitespaces) == want
        }
    }

    @Test("A hook stays live; a setting is commented")
    func hookLiveSettingCommented() {
        let adopted = adopt(
            """
            KiwiDesk.set_gap_global(8)
            KiwiDesk.on("space_changed", function() print("x") end)
            """
        )
        #expect(isCommented("KiwiDesk.set_gap_global(8)", in: adopted))
        #expect(
            isLive(
                "KiwiDesk.on(\"space_changed\", function() "
                    + "print(\"x\") end)",
                in: adopted
            )
        )
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("A multi-line hook stays fully live")
    func multiLineHookLive() {
        let source = """
            KiwiDesk.on("window_focused", function(win)
                os.execute("sketchybar --trigger focus")
            end)
            """
        let adopted = adopt(source)
        for line in source.components(separatedBy: "\n") {
            #expect(isLive(line, in: adopted))
        }
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("A multi-line bind is fully commented")
    func multiLineBindCommented() {
        let source = """
            KiwiDesk.bind("alt+h", function()
                KiwiDesk.focus("left")
            end)
            """
        let adopted = adopt(source)
        // Every line of the bind statement is commented, so no
        // orphaned `end)` is left live to break the file.
        #expect(
            isCommented(
                "KiwiDesk.bind(\"alt+h\", function()",
                in: adopted
            )
        )
        #expect(
            isCommented("KiwiDesk.focus(\"left\")", in: adopted)
        )
        #expect(isCommented("end)", in: adopted))
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("Mixed file: settings + bind commented, hook + print live")
    func mixedFile() {
        let adopted = adopt(
            """
            KiwiDesk.set_gap_global(6)
            bsp.set_ratio_h(0.6)
            KiwiDesk.bind("alt+j", function() KiwiDesk.focus("down") end)
            print("loaded")
            KiwiDesk.on("space_changed", function() print("s") end)
            """
        )
        #expect(isCommented("KiwiDesk.set_gap_global(6)", in: adopted))
        #expect(isCommented("bsp.set_ratio_h(0.6)", in: adopted))
        #expect(
            isCommented(
                "KiwiDesk.bind(\"alt+j\", function() "
                    + "KiwiDesk.focus(\"down\") end)",
                in: adopted
            )
        )
        #expect(isLive("print(\"loaded\")", in: adopted))
        #expect(
            isLive(
                "KiwiDesk.on(\"space_changed\", function() "
                    + "print(\"s\") end)",
                in: adopted
            )
        )
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("A hook whose body calls set_ still stays live")
    func hookWithInnerSettingStaysLive() {
        // Classification keys on the head line, so the inner
        // `set_mode` doesn't demote the hook to managed.
        let source = """
            KiwiDesk.on("space_changed", function()
                KiwiDesk.set_mode("bsp")
            end)
            """
        let adopted = adopt(source)
        for line in source.components(separatedBy: "\n") {
            #expect(isLive(line, in: adopted))
        }
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("A multi-line app_rules table is fully commented")
    func appRulesTableCommented() {
        let source = """
            app_rules = {
                ["Finder"] = "1",
            }
            """
        let adopted = adopt(source)
        for line in source.components(separatedBy: "\n") {
            #expect(isCommented(line, in: adopted))
        }
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("Structural anomaly falls back to commenting everything")
    func anomalyFallsBackToFullComment() {
        // A stray unbalanced `)` makes span depth go negative;
        // adopt must fall back to commenting the whole file rather
        // than leave anything live — and the result is not foreign.
        let source = """
            KiwiDesk.on("x", function() end))
            print("after")
            """
        let adopted = adopt(source)
        for line in source.components(separatedBy: "\n") where !line.isEmpty {
            #expect(isCommented(line, in: adopted))
        }
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("A managed token inside a string forces full fallback")
    func stringMentionForcesFallback() {
        // The foreign net (`hasForeignCode`) scans strings too, so
        // a hook that merely *mentions* `app_rules =` in a string
        // trips it and the whole file falls back to full-comment
        // (safe direction — no live foreign — but the hook is
        // silenced). Documented accepted limitation (#355).
        let adopted = adopt(
            """
            KiwiDesk.on("x", function()
                print("sets app_rules = 1")
            end)
            """
        )
        #expect(
            isCommented("KiwiDesk.on(\"x\", function()", in: adopted)
        )
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("An unbalanced long string trips the anomaly fallback")
    func longStringAnomalyFallsBack() {
        // `codeOnly` doesn't model `[[ … ]]`, so the stray `)`
        // drives depth negative → statementSpan nil → full-comment
        // fallback. Still never foreign.
        let adopted = adopt("x = [[ ) ]]\nprint(\"after\")")
        #expect(isCommented("x = [[ ) ]]", in: adopted))
        #expect(isCommented("print(\"after\")", in: adopted))
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }

    @Test("The adopted file carries a dated header")
    func header() {
        let adopted = adopt("print(\"x\")")
        #expect(adopted.contains("Adopted by KiwiDesk on 2026-07-18"))
    }

    @Test("An empty config adopts to just the header")
    func emptySource() {
        let adopted = adopt("")
        #expect(adopted.contains("Adopted by KiwiDesk on"))
        #expect(!ManagedConfig.hasForeignCode(adopted))
    }
}
