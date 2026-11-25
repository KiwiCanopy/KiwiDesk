import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Standard notice's gate, words and wiring (#3646). The
/// window itself is never shown here; the gate and the words are
/// what decide whether and what it says.
@MainActor
@Suite("Standard notice (#3646)")
struct StandardFallbackNoticeTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("a count is shown once on this Mac")
    func oncePerCount() {
        let (defaults, name) = makeScratchDefaults()
        defer { TestScratch.remove(name) }
        #expect(gate(1, defaults: defaults))
        StandardFallbackShown.markShown(1, in: defaults)
        StandardFallbackShown.markShown(1, in: defaults)
        #expect(!gate(1, defaults: defaults))
        #expect(gate(2, defaults: defaults))
        #expect(
            defaults.array(forKey: StandardFallbackShown.key)
                as? [Int] == [1]
        )
    }

    @Test("the tour and an open notice hold it back")
    func standsDown() {
        let (defaults, name) = makeScratchDefaults()
        defer { TestScratch.remove(name) }
        #expect(!gate(1, tour: true, defaults: defaults))
        #expect(!gate(1, showing: true, defaults: defaults))
        #expect(!StandardFallbackShown.wasShown(1, in: defaults))
    }

    @Test("the words take the count's plural form")
    func pluralForms() {
        LocalizationManager.shared.select("en")
        #expect(StandardFallbackWords.title(1) == "Spaces for 1 Screen")
        #expect(StandardFallbackWords.title(2) == "Spaces for 2 Screens")
        #expect(
            StandardFallbackWords.lead(3)
                == "KiwiDesk set up Spaces for 3 screens."
        )
        #expect(StandardFallbackWords.body(1).contains("this screen's"))
        #expect(StandardFallbackWords.body(2).contains("these screens'"))
        #expect(StandardFallbackWords.help(2).contains("2 screens are"))
    }

    @Test("the body names Settings' own save button")
    func bodyNamesTheButton() {
        LocalizationManager.shared.select("en")
        let save = L("footer.save_as_new_profile", "Save as New Profile…")
        #expect(StandardFallbackWords.body(1).contains(save))
        #expect(StandardFallbackWords.body(2).contains(save))
    }

    @Test("Core's hook reaches the gated present")
    func wiring() throws {
        let delegate = try source("Sources/KiwiDesk/AppDelegate.swift")
        #expect(delegate.contains("wireStandardFallbackNotice()"))
        let wire = try source(
            "Sources/KiwiDesk/AppDelegate+StandardFallback.swift"
        )
        #expect(wire.contains("core.onStandardFallback={"))
        #expect(wire.contains("StandardFallbackNotice.present("))
        #expect(wire.contains("onboardingWindow?.isVisible==true"))
        let notice = try source(
            "Sources/KiwiDesk/StandardFallbackNotice.swift"
        )
        #expect(notice.contains("guardshouldPresent("))
        #expect(notice.contains("noticeShowing:open!=nil"))
    }

    private func gate(
        _ count: Int,
        tour: Bool = false,
        showing: Bool = false,
        defaults: UserDefaults
    ) -> Bool {
        StandardFallbackNotice.shouldPresent(
            count: count,
            tourShowing: tour,
            noticeShowing: showing,
            defaults: defaults
        )
    }

    /// The file with comments stripped and whitespace removed.
    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        ).filter { !$0.isWhitespace }
    }
}
