import Foundation
import Testing

@testable import KiwiDesk

/// Both Restore Defaults surfaces ask before another profile changes
/// (#3248): the gesture card restores at once only while nobody else
/// changed its seeds, and the Shortcuts dialog offers "every profile"
/// only beside "this profile". `RestoreReachTests` holds what each
/// answer writes; this holds that the views reach the answers.
@Suite("Restore Defaults asks at both surfaces (#3248)")
struct RestoreReachWiringTests {
    private func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent("Sources/KiwiDesk/Settings/")
                    .appendingPathComponent(path),
                encoding: .utf8
            )
        ).filter { !$0.isWhitespace }
    }

    @Test("the gesture card asks only while another profile changed")
    func gestureCardAsks() throws {
        let card = try source("Components/Gestures/GestureListCard.swift")
        #expect(
            card.contains(
                "letothers=model.gestureRestoreChangedElsewhere(on:device)"
                    + "ifothers.isEmpty{restore(.here)}else{elsewhere=others}"
            )
        )
        // The card writes through the model's door, never the map.
        #expect(!card.contains("GestureListEdits.restoreDefaults("))
        #expect(card.contains("restore(.everyProfile)"))
        #expect(card.contains(".keyboardShortcut(.defaultAction)"))
    }

    @Test("the Shortcuts dialog splits its Restore only when asked to")
    func shortcutsDialogSplits() throws {
        let row = try source("Sections/DefaultShortcutsRow.swift")
        #expect(
            row.contains(
                "elsewhere=model.shortcutsRestoreChangedElsewhere"
                    + "lostElsewhere=elsewhere.isEmpty?0:"
                    + "model.shortcutsRestoreLostElsewhere"
                    + "confirmingReset=true"
            )
        )
        #expect(
            row.contains("ifletprofile=model.reachProfile,!elsewhere.isEmpty{")
        )
        #expect(
            row.components(separatedBy: "reach:.everyProfile").count == 2
        )
        #expect(!row.contains("resetShortcutsToDefaults()"))
        // What "every profile" takes elsewhere is said in the message.
        #expect(row.contains("RestoreReachWords.lostElsewhere(lostElsewhere)"))
    }
}
