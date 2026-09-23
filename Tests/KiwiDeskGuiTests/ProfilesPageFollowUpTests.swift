import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Two owner rulings from the #1609 eyeball (2026-09-24): the
/// Desktops card opens on what the user has set, and "make
/// default" names the screen count a default is for.
@MainActor
@Suite("Profiles page follow-ups (#1609 eyeball)")
struct ProfilesPageFollowUpTests {
    private func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/" + path
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    @Test("the Desktops card starts collapsed until a binding exists")
    func desktopsCardOpensOnABinding() throws {
        #expect(!DesktopsGroup.startsExpanded(bindings: [:]))
        #expect(
            DesktopsGroup.startsExpanded(
                bindings: [
                    .number(1): DesktopBinding(profile: "P", desktop: 1)
                ]
            )
        )
        // The card's own state takes that decision from the draft.
        let card = try source("Components/Profiles/DesktopsGroup.swift")
        #expect(
            card.contains(
                "initialValue:Self.startsExpanded(bindings:"
                    + "model.config.profileBindings)"
            )
        )
    }

    @Test("make default names the screen count it is for")
    func makeDefaultNamesTheCount() throws {
        LocalizationManager.shared.select("en")
        let section = ProfilesSection(
            model: makeTestModel(
                core: makeTestCore(
                    configDirectory: FileManager.default
                        .temporaryDirectory
                        .appendingPathComponent(
                            "kiwi-default-\(UUID().uuidString)"
                        )
                )
            )
        )
        #expect(
            section.makeDefaultTitle(1) == "make default for 1 screen"
        )
        #expect(
            section.makeDefaultTitle(2) == "make default for 2 screens"
        )
        let actions = try source("Sections/ProfilesSection+RowActions.swift")
        #expect(actions.contains("Text(makeDefaultTitle(summary.count))"))
    }
}
