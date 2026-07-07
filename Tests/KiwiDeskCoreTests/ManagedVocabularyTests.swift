import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Mirror helper

/// Enables the Mirror-based field-population check in
/// `allFieldsNonDefault` without losing type information when
/// iterating `Mirror.children` (whose values are `Any`).
private protocol EmptyCheckable {
    var anyIsEmpty: Bool { get }
}

extension Array: EmptyCheckable {
    var anyIsEmpty: Bool { isEmpty }
}

extension Dictionary: EmptyCheckable {
    var anyIsEmpty: Bool { isEmpty }
}

extension Set: EmptyCheckable {
    var anyIsEmpty: Bool { isEmpty }
}

// MARK: - Fixture

/// Exercises every `GuiConfig` stored property with a
/// non-default value so the Mirror-based guard in
/// `allFieldsNonDefault` can detect a newly-added field
/// that the author forgot to populate here.
private func vocabConfig() -> GuiConfig {
    var c = GuiConfig()
    // Global fields (sidecar / LuaConfigWriter):
    c.spaces = [SpaceID(1), SpaceID(2)]
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
    // Profile-scoped fields (don't affect the Lua block
    // but must be non-default so a future writer that
    // starts reading them is caught by the parity test):
    c.spaceModes = [SpaceID(2): .stack]
    c.spacePins = [SpaceID(1): "A:100x100"]
    c.mainSpaces = [SpaceID(2)]
    var s = TilingSettings()
    s.gapsGlobal = .uniform(8)
    c.settings = s
    return c
}

// MARK: - Parity suite

/// Verifies that every top-level construct `LuaConfigWriter`
/// emits into a managed block is covered by at least one
/// token in `ManagedConfig.managedTokens`, and that the
/// `vocabConfig()` fixture populates every `GuiConfig` stored
/// property — so a future `LuaConfigWriter` branch gated on
/// a new field that the author forgets to populate in the
/// fixture does not silently pass green.
@Suite("Managed-vocabulary parity")
struct ManagedVocabularyTests {
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
            let trimmed = line.trimmingCharacters(
                in: .whitespaces
            )
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix("--") else { continue }
            // Skip indented lines (table entries, bodies).
            guard
                line.first != " ", line.first != "\t"
            else { continue }
            // Skip structural closing tokens: } closes a
            // table/mode block; end closes a function body.
            // These are not top-level vocabulary markers.
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

    /// Mirror-based guard: every `GuiConfig` stored property
    /// must be non-default in `vocabConfig()`. A collection
    /// or set field that is left empty fails here immediately,
    /// which forces the author to populate it and — if the
    /// writer starts reading that field — to add a matching
    /// entry to `managedTokens` so `tokensAppearInGeneratedBlock`
    /// also catches the drift.
    ///
    /// Limitation: the Mirror net catches a missing *property*,
    /// not a forgotten line in `encode`/`resolved()`. The
    /// struct `settings` cannot be compared through `Any`, so
    /// it is checked directly below the loop.
    @Test(
        "every GuiConfig field is non-default in vocabConfig()"
    )
    func allFieldsNonDefault() {
        let config = vocabConfig()
        for child in Mirror(reflecting: config).children {
            guard let label = child.label else { continue }
            if let c = child.value as? EmptyCheckable {
                #expect(
                    !c.anyIsEmpty,
                    "GuiConfig.\(label) empty — populate vocabConfig()"
                )
            }
        }
        // Non-collection struct: compared directly because
        // Swift can't use Equatable through Any.
        #expect(
            config.settings != TilingSettings(),
            "settings is still default in vocabConfig()"
        )
    }
}
