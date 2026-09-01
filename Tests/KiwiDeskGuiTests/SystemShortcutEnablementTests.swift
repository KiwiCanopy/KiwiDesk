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
        // Invert Colors (21) enabled by the user → not disabled.
        let withInvert = SystemShortcutEnablement.disabled(
            reading: { id in id == 21 ? true : nil }
        )
        #expect(!withInvert.contains(.invertColors))
        #expect(withInvert.contains(.increaseContrast))
        // Spotlight (64) switched off → joins the set.
        let noSpotlight = SystemShortcutEnablement.disabled(
            reading: { id in id == 64 ? false : nil }
        )
        #expect(noSpotlight.contains(.spotlight))
    }

    /// ⌘Q, ⌘Tab and friends are not symbolic hotkeys — no plist
    /// answer can disable them, however the reader answers.
    @Test("a hard-wired chord can never be disabled")
    func hardWiredChordsNeverDisable() {
        let all = SystemShortcutEnablement.disabled(
            reading: { _ in false }
        )
        let hardWired = SystemShortcut.allCases.filter {
            $0.symbolicHotkey == nil
        }
        #expect(hardWired.contains(.quitApp))
        #expect(hardWired.contains(.appSwitcher))
        for shortcut in hardWired {
            #expect(!all.contains(shortcut))
        }
        // …and everything WITH an id is in the set, so the
        // filter above is the only thing keeping them out.
        for shortcut in SystemShortcut.allCases
        where shortcut.symbolicHotkey != nil {
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

/// The routing half (#1094's lesson, restated by #1105): there
/// are three aggregate conflict surfaces and the first fix wired
/// only one of them, so the live-state read must have ONE home a
/// reader cannot skip.
@Suite("Conflict accessor routing")
struct ConflictAccessorRoutingTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func stripped(_ path: String) throws -> String {
        let url = root.appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }

    /// `KeybindingConflicts.actionable(` appears in the GUI tree
    /// exactly once — inside `actionableConflicts()`, threading
    /// the injected reader. A second caller is a surface that
    /// can forget the live state.
    @Test("the Core filter has one GUI caller, and it threads")
    func actionableHasOneCaller() throws {
        let sources = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDesk"
            )
        )
        var hits = 0
        for url in sources {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            hits +=
                text.components(
                    separatedBy: "KeybindingConflicts.actionable("
                ).count - 1
        }
        #expect(hits == 1)
        let accessor = try Self.stripped(
            "Sources/KiwiDesk/Settings/"
                + "SettingsModel+ConflictMessages.swift"
        )
        #expect(
            accessor.contains(
                "KeybindingConflicts.actionable("
                    + "in:config.layers,"
                    + "disabledSystemShortcuts:"
                    + "SystemShortcutEnablement.disabled("
                    + "reading:readSymbolicHotkey))"
            )
        )
    }

    /// The production default is the LIVE read — a seam declared
    /// and defaulted inert would go one-toggle-wrong for every
    /// user (#1105) — and `makeTestModel` is what keeps that
    /// live default out of every suite.
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
