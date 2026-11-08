import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The hint panel's step (#1871 ▸ hint panel): read from the stored
/// tree the progress names, branches apart from end keys. Main
/// actor for `ChordGlyphs`; it spends a few tree walks.
@MainActor
@Suite("Key sequence hint")
struct KeySequenceHintTests {
    static let layer = KeyLayer(
        name: "default",
        bindings: [
            KeyBinding(combo: "alt+h", lua: "KiwiDesk.focus(\"left\")"),
            .sequence(
                combo: "ctrl+alt+space",
                label: "Leader",
                steps: [
                    .sequence(
                        combo: "w",
                        label: "Windows",
                        steps: [
                            KeyBinding(
                                combo: "h",
                                lua: "KiwiDesk.focus(\"left\")"
                            )
                        ]
                    ),
                    KeyBinding(combo: "t", lua: "KiwiDesk.toggle_float()"),
                ]
            ),
        ]
    )

    @Test("The first step lists its branch apart from its end keys")
    func firstStep() throws {
        LocalizationManager.shared.select("en")
        let hint = try #require(
            KeySequenceHint.of(
                KeySequenceProgress(leader: "ctrl+alt+space", path: []),
                in: Self.layer
            )
        )
        #expect(hint.title == "Leader")
        #expect(hint.branches.map(\.name) == ["Windows"])
        #expect(hint.endKeys.bindings.map(\.combo) == ["t"])
        #expect(hint.crumbs.count == 1)
    }

    @Test("A step down names its path in the breadcrumb")
    func stepDown() throws {
        LocalizationManager.shared.select("en")
        let hint = try #require(
            KeySequenceHint.of(
                KeySequenceProgress(leader: "ctrl+alt+space", path: ["w"]),
                in: Self.layer
            )
        )
        #expect(hint.crumbs.map(\.name) == ["Leader", "Windows"])
        #expect(hint.breadcrumb.hasSuffix(" › W Windows"))
        #expect(hint.branches.isEmpty)
        #expect(hint.endKeys.bindings.map(\.combo) == ["h"])
    }

    @Test("A path the tree no longer holds draws nothing")
    func stalePath() {
        #expect(
            KeySequenceHint.of(
                KeySequenceProgress(leader: "ctrl+alt+space", path: ["t"]),
                in: Self.layer
            ) == nil
        )
        #expect(
            KeySequenceHint.of(
                KeySequenceProgress(leader: "ctrl+alt+k", path: []),
                in: Self.layer
            ) == nil
        )
    }

    @Test("An unnamed leader is titled by its chord")
    func unnamedLeader() throws {
        var layer = Self.layer
        layer.bindings[1].label = ""
        let hint = try #require(
            KeySequenceHint.of(
                KeySequenceProgress(leader: "ctrl+alt+space", path: []),
                in: layer
            )
        )
        #expect(hint.title == hint.crumbs[0].chord)
        #expect(!hint.title.isEmpty)
    }

    @Test("The app hands Core's progress to the hint panel")
    func wiring() throws {
        let text = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/AppDelegate.swift")
        )
        #expect(text.contains("core.onKeySequence = {"))
        #expect(text.contains("self?.keySequenceHint.follow(progress)"))
    }
}
