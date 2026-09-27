import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// After an install from the update window, the relaunch opens
/// "What's new" at once and narrates boot (#1667 ruling).
@MainActor
@Suite("What's new narrates the relaunch (#1667)", .serialized)
struct WhatsNewRelaunchTests {
    private static func relaunch(
        _ version: String,
        since: String = "9999.1.0"
    ) -> WhatsNewRecord.Relaunch {
        .init(
            version: version,
            since: since,
            items: WhatsNewFixture.items([version, since])
        )
    }

    @Test("the relaunch opens from the carried notes, without a fetch")
    func relaunchOpensWithoutFetch() throws {
        let (coordinator, record, log) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: nil
        )
        record.markSeen("9999.2.0")
        record.markRelaunch(Self.relaunch("9999.2.0"))
        var shown: WhatsNewWindowController?
        coordinator.presents = {
            shown = $0
            log.presented += 1
        }
        let narration = BootNarration(
            phase: .scanning(scanned: 2, total: 9)
        )
        let narrated = coordinator.relaunched(
            opensWindow: true,
            narration: narration
        )
        #expect(narrated)
        #expect(log.presented == 1)
        // The window carries the narration it was handed.
        #expect(shown?.narration === narration)
        #expect(coordinator.waiting?.digest?.versions == ["9999.2.0"])
        // Read once.
        #expect(record.takeRelaunch() == nil)
    }

    @Test("under the tour it waits behind the mark")
    func tourKeepsTheScreen() throws {
        let (coordinator, record, log) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: nil
        )
        record.markRelaunch(Self.relaunch("9999.2.0"))
        #expect(
            coordinator.relaunched(
                opensWindow: false,
                narration: BootNarration()
            )
        )
        #expect(log.presented == 0)
        #expect(coordinator.waiting != nil)
    }

    /// The install never landed, and another build arrived by
    /// some other route — one the carried feed happens to list.
    @Test("a record for another version narrates nothing, and goes")
    func staleRecordIsDropped() throws {
        let (coordinator, record, log) = try WhatsNewFixture.coordinator(
            current: "9999.1.0",
            lastRun: "9999.0.0",
            feed: nil
        )
        record.markRelaunch(
            .init(
                version: "9999.2.0",
                since: "9999.0.0",
                items: WhatsNewFixture.items(
                    ["9999.2.0", "9999.1.0", "9999.0.0"]
                )
            )
        )
        #expect(
            !coordinator.relaunched(
                opensWindow: true,
                narration: BootNarration()
            )
        )
        #expect(log.presented == 0)
        #expect(record.takeRelaunch() == nil)
    }

    @Test("the line is the tour's count, and drops once boot is ready")
    func lineIsTheToursCount() {
        LocalizationManager.shared.select("en")
        let narration = BootNarration(
            phase: .scanning(scanned: 3, total: 9)
        )
        #expect(narration.line == "Going through your open apps: 3 of 9")
        narration.phase = .ready
        #expect(narration.line == nil)
        narration.phase = .idle
        #expect(narration.line == nil)
    }

    /// The line reaches the header's subtitle slot, and outranks
    /// the release date while it lasts.
    @Test("the header draws the narration")
    func headerDrawsTheNarration() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let source = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Updates/UpdateWindowView.swift"
            )
        )
        #expect(source.contains("case .whatsNew(let narration, let done)"))
        #expect(source.contains("narration: narration.line"))
        let subtitle = try #require(
            SourceScan.declarationBody(
                after: "private var subtitle: String",
                in: source
            )
        )
        let first = subtitle.drop { $0 == "{" || $0.isWhitespace }
        #expect(first.hasPrefix("if let narration { return narration }"))
    }

    /// The grant screen and the header read the one sentence.
    @Test("the grant screen reads the one author of the count")
    func grantReadsTheOneAuthor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let grant = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Onboarding/OnboardingView+Grant.swift"
            )
        )
        #expect(grant.contains("BootCountText.line(for: model.bootPhase)"))
        let narration = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Updates/BootNarration.swift"
            )
        )
        #expect(narration.contains("BootCountText.line(for: phase)"))
        #expect(!grant.contains("onboarding.grant.arranging.count"))
        let chrome = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Updates/UpdateWindowChrome.swift"
            )
        )
        #expect(chrome.contains("mode: .whatsNew(narration: narration)"))
    }
}
