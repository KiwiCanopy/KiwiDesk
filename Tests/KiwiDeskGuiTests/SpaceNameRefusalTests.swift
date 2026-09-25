import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A rename to a taken Space name is said, not only refused
/// (#1623): the field derives its notice from the draft, and the
/// row draws what it reports.
@Suite("Space rename refusal caption (#1623)", .serialized)
@MainActor
struct SpaceNameRefusalTests {
    /// The app's own shape: the row's Space is in the set too.
    private let taken: Set<SpaceID> = [
        SpaceID("Mail"), SpaceID("Work"), SpaceID(2),
    ]

    private func notice(_ draft: String) -> SpaceNameNotice? {
        SpaceNameNotice.of(
            draft: draft,
            space: SpaceID("Mail"),
            isAvailable: { !taken.contains($0) }
        )
    }

    @Test("a taken name is a refusal naming the draft")
    func takenNameIsRefused() {
        LocalizationManager.shared.select("xx-not-a-real-locale")
        defer { LocalizationManager.shared.select(nil) }
        #expect(notice("  Work ") == .taken("Work"))
        #expect(notice("2") == .taken("2"))
        #expect(notice("Work")?.isRefusal == true)
        #expect(
            notice("Work")?.sentence
                == "A Space named “Work” already exists."
        )
    }

    @Test("an empty draft is a hint naming the name it keeps")
    func emptyDraftIsAHint() {
        LocalizationManager.shared.select("xx-not-a-real-locale")
        defer { LocalizationManager.shared.select(nil) }
        #expect(notice("   ") == .empty(keeping: "Mail"))
        #expect(notice("")?.isRefusal == false)
        #expect(
            notice("")?.sentence
                == "Type a name, or it goes back to “Mail”."
        )
    }

    @Test("free and unchanged drafts earn nothing")
    func otherDraftsAreSilent() {
        #expect(notice("Music") == nil)
        #expect(notice("Mail") == nil)
    }

    @Test("the field reports its notice, retires it, and speaks it")
    func fieldWiresItsNotice() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/SpaceNameField.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let changed = SourceScan.declarationBody(
            after: ".onChange(of: notice)",
            in: source
        )
        #expect(changed?.contains("onNotice(notice)") == true)
        let gone = SourceScan.declarationBody(
            after: ".onDisappear",
            in: source
        )
        #expect(gone?.contains("onNotice(nil)") == true)
        let commit = try #require(
            SourceScan.declarationBody(
                after: "private func commit()",
                in: source
            )
        )
        let refused = SourceScan.declarationBody(
            after: "if let refusal = notice(for: draft), refusal.isRefusal",
            in: commit
        )
        #expect(
            refused?.contains("DelayedAnnouncement.schedule(") == true
        )
        #expect(refused?.contains("refusal.sentence") == true)
    }

    @Test("the caption is danger with its shape cue")
    func captionCarriesTheWarningShape() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/SpaceNameNotice.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let caption = try #require(
            SourceScan.declarationBody(
                after: "struct SpaceNameNoticeCaption",
                in: source
            )
        )
        #expect(caption.contains("exclamationmark.triangle.fill"))
        #expect(caption.contains(".foregroundStyle(SettingsTheme.danger)"))
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
