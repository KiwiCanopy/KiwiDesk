import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A rename to a taken Space name is said, not only refused
/// (#1623): the field derives the caption from its draft, and the
/// row draws what the field reports beneath it.
@Suite("Space rename refusal caption (#1623)", .serialized)
@MainActor
struct SpaceNameRefusalTests {
    private let taken: Set<SpaceID> = [SpaceID("Work"), SpaceID(2)]

    private func notice(_ draft: String) -> String? {
        SpaceNameField.takenNotice(
            draft: draft,
            space: SpaceID("Mail"),
            isAvailable: { !taken.contains($0) }
        )
    }

    @Test("a taken name earns the sentence, naming the draft")
    func takenNameIsSaid() {
        LocalizationManager.shared.select("xx-not-a-real-locale")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            notice("  Work ") == "A Space named “Work” already exists."
        )
        #expect(notice("2") == "A Space named “2” already exists.")
    }

    @Test("free, unchanged and empty drafts earn no sentence")
    func otherDraftsAreSilent() {
        LocalizationManager.shared.select("xx-not-a-real-locale")
        defer { LocalizationManager.shared.select(nil) }
        #expect(notice("Music") == nil)
        #expect(notice("Mail") == nil)
        #expect(notice("   ") == nil)
    }

    @Test("the row draws what its field reports")
    func rowDrawsTheReportedNotice() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/SpacesSection.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        #expect(
            source.occurrences(
                of: "onNotice: { renameNotices[space] = $0 }"
            ) == 1
        )
        #expect(
            source.occurrences(
                of: "if let notice = renameNotices[space]"
            ) == 1
        )
    }
}
