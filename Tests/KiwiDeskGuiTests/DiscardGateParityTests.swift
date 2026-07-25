import Foundation
import Testing

/// Every GUI action that ends in `reload()` drops the user's
/// staged edits, so every one must route through
/// `SettingsModel.discardingEdits` (#515). A behavioural test
/// cannot see that — it can only check the gate a call site
/// chose to use — so this guard scans the source instead.
///
/// **The lens, not the list.** A hand-enumerated "these seven
/// buttons are gated" would be fail-OPEN for the case that
/// matters: an eighth path added later appears in neither the
/// list nor the index, so nothing examines it. This guard
/// instead discovers *every* occurrence of each destructive
/// call and requires it to sit inside a `discardingEdits`
/// closure — so a new ungated call site fails on arrival. It
/// earned that design immediately: the broken-profile Delete
/// (`ProfilesSection+Broken.swift`) was a seventh path the #406
/// audit's hand-traced list missed, and this guard found it.
///
/// An eighth, `adoptIntoGui`, was found by a human reviewer —
/// NOT by this guard, which had no token for it. That is the
/// honest record, and the reason its token is listed below with
/// an expected count of 0 rather than left out.
///
/// Known limits, all of which fail **shut**:
/// - Lexical. A destructive call reached through a helper that
///   is itself called outside a gate reads as gated, as does one
///   nested in a sub-closure inside a gate body.
/// - Receiver-name coupling: the needles assume the model is
///   bound as `model`. A call through another binding name or
///   `self.` is invisible. This is the likelier hole in practice
///   — prefer `model` as the binding name in Settings views.
/// - Needles are whitespace-exact, so a §2.2 hard wrap between
///   `model.showLuaEditor =` and `true` would hide that site.
///   The per-token count assertions below are what catch it.
@Suite("Discard gate call-site parity")
struct DiscardGateParityTests {
    /// The model calls whose tail is `reload()` — each drops
    /// staged edits and clears `isDirty` — with the exact number
    /// of gated occurrences expected today.
    ///
    /// Pinned per token, not as an aggregate: a loose floor lets
    /// a single token go dead (renamed method, rewrapped line)
    /// while the suite stays green, so the guard would quietly
    /// stop guarding that path.
    private let destructive: [(call: String, expected: Int)] = [
        ("model.showLuaEditor = true", 1),
        ("model.loadProfile(", 1),
        ("model.deleteProfile(", 2),
        ("model.renameProfile(", 1),
        ("model.applyStandardPreset(", 1),
        ("model.selectEditTarget(", 1),
        // The broad net the header promises. Everything above is
        // reachable through this one, but naming them separately
        // is what makes a dead token visible.
        ("model.reload()", 2),
        // Expected 0: its only call site is exempted below. The
        // token is listed anyway, because `exempt` is consulted
        // ONLY for tokens in this list — omitting it made the
        // exemption dead and left the path unscanned. Listed, a
        // SECOND adopt call site anywhere breaks the count.
        ("model.adoptIntoGui(", 0),
    ]

    /// Exempted per FILE AND TOKEN, never a whole file — a
    /// file-level exemption in a fail-shut guard blinds every
    /// future call in that file, which is the opposite of what
    /// an exemption should cost.
    private let exempt: [String: Set<String>] = [
        // Adopt migrates the file on DISK into GUI management
        // and keeps its OWN confirmation, whose message now
        // names the dropped buffer when the model is dirty
        // (#515 review). Stacking the shared gate on top would
        // prompt twice for one gesture.
        "LuaEditorTab.swift": ["model.adoptIntoGui("],
        // Deliberately guarded by `if !model.isDirty` instead:
        // reopening the window must pick up external edits
        // without ever discarding staged ones (#455).
        "SettingsWindowController.swift": ["model.reload()"],
    ]

    @Test("every destructive call sits inside the gate")
    func destructiveCallsAreGated() throws {
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(
            under: settingsDir
        ) {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let gated = gateClosures(in: source)
                .joined(separator: "\n")
            for (call, _) in destructive {
                let total = source.occurrences(of: call)
                guard total > 0 else { continue }
                if exempt[name]?.contains(call) == true {
                    continue
                }
                counts[call, default: 0] += total
                #expect(
                    gated.occurrences(of: call) == total,
                    Comment(
                        rawValue:
                            "ungated discard path: \(call) in "
                            + name
                    )
                )
            }
        }
        // A scan that matches nothing passes vacuously — the
        // failure mode that let the sidebar-search guard sit
        // blind for three drawers.
        for (call, expected) in destructive {
            #expect(
                counts[call, default: 0] == expected,
                Comment(
                    rawValue:
                        "\(call): found "
                        + "\(counts[call, default: 0]) gated "
                        + "site(s), expected \(expected) — a "
                        + "path was added, removed, or the "
                        + "needle went stale"
                )
            )
        }
    }

    /// `adoptIntoGui` is exempted from the shared gate because
    /// it carries its own dialog — so that dialog must name the
    /// loss. Pinned here, beside the exemption that depends on
    /// it, rather than in a suite nobody reads next to it.
    @Test("the adopt exemption still warns about the buffer")
    func adoptDialogNamesTheDroppedBuffer() throws {
        let file = settingsDir.appendingPathComponent(
            "Components/Lua/LuaEditorTab.swift"
        )
        // Comments stripped, like the sibling scan: a doc
        // comment mentioning either token must not keep this
        // green after the code it describes is deleted.
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(source.contains("lua_editor.adopt.message_dirty"))
        #expect(source.contains("model.isDirty"))
    }

    /// The trailing closure of every `discardingEdits(…) { … }`
    /// call, found by walking `(…)` then `{…}` nesting. A flat
    /// regex cannot do this: the argument list spans lines and
    /// contains its own braces and parens inside `L(…)` strings.
    private func gateClosures(in source: String) -> [String] {
        let text = Array(source)
        let needle = Array("discardingEdits")
        var found: [String] = []
        var i = 0
        while i + needle.count <= text.count {
            guard Array(text[i..<(i + needle.count)]) == needle
            else {
                i += 1
                continue
            }
            var cursor = i + needle.count
            guard
                SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                ) != nil,
                let body = SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "{",
                    close: "}"
                )
            else {
                i += needle.count
                continue
            }
            found.append(body)
            i = cursor
        }
        return found
    }

    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }
}
