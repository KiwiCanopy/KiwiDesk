import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Desktop families' one explanation (#1114): a `?` on the
/// macOS Desktops section header (#2655), carrying what a Desktop
/// is against a Space.
///
/// Separate from `MacOSDesktopsSectionTests`, which owns whether
/// the section draws. This owns what its header says.
///
/// The scan watches PLACEMENT, which has no runtime value to
/// compare: the sentence is the section's `help:` argument — the
/// header's `?`, never a row inside the card — handed `helpText`
/// itself, and the file carries no second door. The interpolation
/// clause compares against the label AS THIS HOST RENDERS IT, so
/// a label hardcoded in the host's own language passes; pinning a
/// locale would only move which language is fooled (round 3,
/// 2026-09-08).
///
/// Main-actor spend (tests.md): one `makeTestModel` build and one
/// `ShortcutsFamilyRows` fixture, plus two source reads.
@MainActor
@Suite("macOS Desktops help")
struct MacOSDesktopsHelpTests {
    private static let groupFile =
        "Sources/KiwiDesk/Settings/Components/Keybindings/"
        + "MacOSDesktopsGroup.swift"

    private static let sectionFile =
        "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"

    private func squashed(_ repoRelative: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The sentence interpolates the profile-binding drawer
    /// rather than quoting it (#818): the label is READ from the
    /// catalog, so this cannot become a second hand-kept copy.
    @Test("the explanation names the profile-binding card")
    func helpNamesTheProfilesCard() {
        let group = MacOSDesktopsGroup(
            model: makeTestModel(),
            bindings: .constant([]),
            expander: ShortcutsFamilyRows(
                spaces: [],
                icons: [:],
                desktops: .init(desktops: [1, 2]),
                resizeStep: 40,
                layerNames: [KeyLayer.defaultName],
                currentLayer: KeyLayer.defaultName
            )
        )
        #expect(!group.helpText.isEmpty)
        #expect(
            group.helpText.contains(
                SettingsCatalog.profiles.desktops.control.text
            )
        )
    }

    /// The `?` is the section header's, handed `helpText` itself:
    /// `explanation: helpText + note` or a second property
    /// rendered instead both shipped two sentences past an earlier
    /// cut (guard-prover round 3, 2026-09-08).
    @Test("the explanation hangs on the section header")
    func helpRidesTheHeader() throws {
        let source = try squashed(Self.groupFile)
        #expect(
            source.contains(
                "SettingsSection(SettingsCatalog.shortcuts"
                    + ".desktopsSection,help:helpText)"
            )
        )
        // The ONLY door in the file: a second `?` inside the card
        // or the drawer leaves the clause above untouched.
        #expect(source.occurrences(of: "help:") == 1)
        #expect(!source.contains("HelpButton("))
        #expect(!source.contains("accessory:"))
    }
}
