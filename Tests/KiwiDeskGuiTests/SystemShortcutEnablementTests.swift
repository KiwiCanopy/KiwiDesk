import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The live half of a conflict verdict (#1105): the shipped
/// defaults, the plist-entry override and the hard-wired chords,
/// all through injected readers — no test reads the host's
/// `com.apple.symbolichotkeys`.
@Suite("System shortcut enablement")
struct SystemShortcutEnablementTests {
    /// The set-equality census of what macOS ships OFF: the Zoom
    /// trio and the Accessibility display trio (#1094's six,
    /// re-measured 2026-09-01, macOS 26.6.2). A new case whose
    /// `symbolicHotkey` answers `shipsEnabled: false` must join
    /// this list consciously.
    @Test("nil answers everywhere = the six dormant chords")
    func shippedDefaultsMatchTheDormantSet() {
        #expect(
            SystemShortcutEnablement.disabled(
                reading: { _ in nil }
            ) == [
                .zoomToggle, .zoomIn, .zoomOut,
                .invertColors, .increaseContrast,
                .decreaseContrast,
            ]
        )
    }

    @Test("a plist entry outranks the shipped default, both ways")
    func plistEntryOutranksTheShippedDefault() {
        let invert = SystemShortcut.invertColors.symbolicHotkey!.id
        let spot = SystemShortcut.spotlight.symbolicHotkey!.id
        // Invert Colors enabled by the user → not disabled.
        let withInvert = SystemShortcutEnablement.disabled(
            reading: { id in id == invert ? true : nil }
        )
        #expect(!withInvert.contains(.invertColors))
        #expect(withInvert.contains(.increaseContrast))
        // Spotlight switched off → joins the set.
        let noSpotlight = SystemShortcutEnablement.disabled(
            reading: { id in id == spot ? false : nil }
        )
        #expect(noSpotlight.contains(.spotlight))
    }

    /// ⌘Q, ⌘Tab and friends are not symbolic hotkeys — no plist
    /// answer can disable them, however the reader answers. The
    /// hard-wired set is pinned BY NAME, not derived from
    /// `symbolicHotkey` (the property under test): a derived set
    /// stays consistent under exactly the mutation this watches.
    @Test("a hard-wired chord can never be disabled")
    func hardWiredChordsNeverDisable() {
        let hardWired: Set<SystemShortcut> = [
            .appSwitcher, .quitApp, .closeWindow,
            .minimize, .hideApp, .forceQuit,
        ]
        #expect(
            Set(
                SystemShortcut.allCases.filter {
                    $0.symbolicHotkey == nil
                }
            ) == hardWired
        )
        let all = SystemShortcutEnablement.disabled(
            reading: { _ in false }
        )
        for shortcut in hardWired {
            #expect(!all.contains(shortcut))
        }
        // …and everything WITH an id is in the set, so the
        // nil filter is the only thing keeping them out.
        for shortcut in SystemShortcut.allCases
        where !hardWired.contains(shortcut) {
            #expect(all.contains(shortcut))
        }
    }

    /// Two cases sharing an id would read one plist entry for
    /// two different chords.
    @Test("symbolic hotkey ids are unique")
    func idsAreUnique() {
        let ids = SystemShortcut.allCases.compactMap {
            $0.symbolicHotkey?.id
        }
        #expect(Set(ids).count == ids.count)
    }
}

/// The routing half (#1094's lesson, restated by #1105): a
/// verdict computed beside the accessor cannot know the live
/// enabled state, so every road to one is pinned — the
/// `KeybindingConflicts` family, the enablement type, and the
/// seam's polarity on both sides.
@Suite("Conflict accessor routing")
struct ConflictAccessorRoutingTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func guiSources() throws -> [URL] {
        try SourceScan.swiftSources(
            under: root.appendingPathComponent("Sources/KiwiDesk")
        )
    }

    private static func stripped(_ path: String) throws -> String {
        let url = root.appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }

    /// Every `KeybindingConflicts.` call in the GUI tree sits on
    /// the allow-list: `conflict` is the per-row entry,
    /// `actionable` lives only inside the accessor. Any other
    /// symbol (`conflicts`, `hasAny`, `hasAnyAcrossLayers`) is
    /// an unfiltered aggregate — #1094 re-opened with the guard
    /// green, which is what the first cut of this scan allowed.
    @Test("every KeybindingConflicts call is on the allow-list")
    func familyAllowList() throws {
        let allowed: [String: Set<String>] = [
            "SettingsModel+ConflictMessages.swift": [
                "actionable", "conflict",
            ],
            "ConflictText.swift": ["conflict"],
        ]
        var actionableHits = 0
        var familyHits = 0
        for url in try Self.guiSources() {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let parts = text.components(
                separatedBy: "KeybindingConflicts."
            ).dropFirst()
            for part in parts {
                familyHits += 1
                let symbol = String(
                    part.prefix {
                        $0.isLetter || $0.isNumber || $0 == "_"
                    }
                )
                let file = url.lastPathComponent
                #expect(
                    allowed[file]?.contains(symbol) == true,
                    Comment(
                        rawValue:
                            "\(file) calls KeybindingConflicts."
                            + symbol
                    )
                )
                if symbol == "actionable" { actionableHits += 1 }
            }
        }
        // The walk found the family at all (an empty scan is a
        // moved directory, not a clean tree)…
        #expect(familyHits >= 3)
        // …and the Core filter has exactly one GUI caller.
        #expect(actionableHits == 1)
    }

    /// The accessor pair threads the injected reader end to
    /// end, and `SystemShortcutEnablement` is reachable only
    /// through it — a site calling `disabled(` or `liveRead`
    /// beside the model bypasses `readSymbolicHotkey` and reads
    /// the host plist in every suite that renders it.
    @Test("the enablement type has one door, and it threads")
    func enablementHasOneDoor() throws {
        let accessor = try Self.stripped(
            "Sources/KiwiDesk/Settings/"
                + "SettingsModel+ConflictMessages.swift"
        )
        #expect(
            accessor.contains(
                "funcactionableConflicts()->[Conflict]{"
                    + "KeybindingConflicts.actionable("
                    + "in:config.layers,"
                    + "disabledSystemShortcuts:"
                    + "disabledSystemShortcuts())}"
            )
        )
        #expect(
            accessor.contains(
                "funcdisabledSystemShortcuts()"
                    + "->Set<SystemShortcut>{"
                    + "SystemShortcutEnablement.disabled("
                    + "reading:readSymbolicHotkey)}"
            )
        )
        var disabledHits = 0
        var liveReadHits = 0
        for url in try Self.guiSources() {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            disabledHits +=
                text.components(
                    separatedBy: "SystemShortcutEnablement.disabled("
                ).count - 1
            liveReadHits +=
                text.components(
                    separatedBy: "SystemShortcutEnablement.liveRead"
                ).count - 1
        }
        #expect(disabledHits == 1)
        #expect(liveReadHits == 1)
    }

    /// The production default is the LIVE read — a seam declared
    /// and defaulted inert would go one-toggle-wrong for every
    /// user (#1105) — `makeTestModel` keeps that default out of
    /// every suite, and the seam takes NO other production
    /// write: the mention count pins declaration + one read, so
    /// a later assignment (returning every user to shipped
    /// defaults) is a third mention and reds.
    @Test("the seam defaults live and tests inject inert")
    func seamPolarity() throws {
        let model = try Self.stripped(
            "Sources/KiwiDesk/Settings/SettingsModel.swift"
        )
        #expect(
            model.contains(
                "varreadSymbolicHotkey:(Int)->Bool?="
                    + "SystemShortcutEnablement.liveRead"
            )
        )
        var mentions = 0
        for url in try Self.guiSources() {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            mentions +=
                text.components(
                    separatedBy: "readSymbolicHotkey"
                ).count - 1
        }
        #expect(mentions == 2)
        let factory = try Self.stripped(
            "Tests/KiwiDeskGuiTests/TestModel.swift"
        )
        #expect(
            factory.contains(
                "model.readSymbolicHotkey={_innil}"
            )
        )
    }
}
