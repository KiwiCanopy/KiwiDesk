import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The macOS Desktops section's drawn branches (#2655). A
/// SURFACING branch leaves nothing behind to prove it was drawn:
/// the resolver's suite, the census parity and the family
/// expansion all pass whether or not the `if` was ever written
/// (the Monitors lesson), so the branches are needled through
/// their bodies, keyed on the use site. What the predicates
/// resolve to is `MacOSDesktopsPredicateTests`'.
///
/// Main-actor spend (tests.md): none — two source reads.
@Suite("macOS Desktops section")
struct MacOSDesktopsSectionTests {
    private func squashed(_ repoRelative: String) throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(repoRelative)
        return SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    private static let group =
        "Sources/KiwiDesk/Settings/Components/Keybindings/"
        + "MacOSDesktopsGroup.swift"

    @Test("the section draws its branches")
    func sectionBranchesAreDrawn() throws {
        let source = try squashed(Self.group)
        // The hold-open is the resolver's, never counted here.
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config)"
                    + ".desktopMovesBound"
            )
        )
        // Removed, not greyed, over no rows; the drawer likewise.
        #expect(source.contains("ifSelf.hasRows(expander){"))
        #expect(source.contains("ifSelf.movesHaveRows(expander){moves}"))
        // The section is the search anchor and carries the help;
        // the switch cue leads it (#2142).
        #expect(
            source.contains(
                "SettingsSection(SettingsCatalog.shortcuts"
                    + ".desktopsSection,help:helpText)"
                    + "{DesktopCueRow(model:model)"
                    + "ForEach(ShortcutsRowOrder.macosDesktopsAtRest,"
                    + "id:\\.id){family($0)}"
            )
        )
        // ONE drawer, mounted in both states, seeded open once a
        // move is bound and never forced shut.
        #expect(source.occurrences(of: "SettingsDisclosure(") == 1)
        #expect(
            source.contains(
                "SettingsDisclosure(SettingsCatalog.shortcuts"
                    + ".desktopMoves,isExpanded:$movesExpanded,"
                    + "scrollHoisted:true){VStack(alignment:.leading,"
                    + "spacing:8){ForEach(ShortcutsRowOrder"
                    + ".macosDesktopsMore,id:\\.id){family($0)}}"
            )
        )
        #expect(
            source.contains(
                ".onAppear{ifmovesBound{movesExpanded=true}}"
            )
        )
        // Its declaration and the hold-open are the only writes.
        #expect(source.occurrences(of: "movesExpanded=") == 2)
        // `family` DRAWS the key: a body reduced to an empty
        // view satisfied every needle above while shipping every
        // Desktop row invisible (guard-prover, 2026-09-04).
        #expect(
            source.contains(
                "privatefuncfamily(_key:SettingKey)->someView{"
                    + "KeybindingFamilyRows(model:model,"
                    + "bindings:$bindings,key:key,"
                    + "expander:expander,showsHeading:false)"
            )
        )
    }

    /// Mounted once, after Move windows; the old drawers gone from
    /// the Focus and Move windows cards.
    @Test("the section is mounted once, after Move windows")
    func sectionIsMountedAfterMoveWindows() throws {
        let section = try squashed(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        #expect(section.occurrences(of: "MacOSDesktopsGroup(") == 1)
        #expect(
            section.contains(
                "MoveWindowsGroup(model:model,"
                    + "bindings:bindingsBinding,expander:expander)"
                    + "MacOSDesktopsGroup(model:model,"
                    + "bindings:bindingsBinding,expander:expander)"
            )
        )
        let groups = try squashed(
            "Sources/KiwiDesk/Settings/Components/Keybindings/"
                + "KeybindingGroups.swift"
        )
        #expect(!groups.contains("macosDesktops"))
        #expect(!groups.contains("MacOSDesktopsGroup"))
    }
}
