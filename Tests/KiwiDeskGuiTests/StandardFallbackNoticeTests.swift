import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Standard notice's admission, window, words and wiring
/// (#3646). The window is built and inspected, never shown.
@MainActor
@Suite("Standard notice (#3646)")
struct StandardFallbackNoticeTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("a count is admitted once on this Mac")
    func oncePerCount() {
        let (defaults, name) = makeScratchDefaults()
        defer { TestScratch.remove(name) }
        #expect(admit(1, defaults: defaults))
        #expect(!admit(1, defaults: defaults))
        #expect(admit(2, defaults: defaults))
        #expect(
            defaults.array(forKey: StandardFallbackShown.key)
                as? [Int] == [1, 2]
        )
    }

    @Test("present shows a count once, and nothing under the tour")
    func presentObeysAdmit() {
        let (defaults, name) = makeScratchDefaults()
        defer { TestScratch.remove(name) }
        var shown: [Int] = []
        let record = { (notice: StandardFallbackNotice) in
            shown.append(notice.fallback.screenCount)
        }
        for _ in 0..<2 {
            StandardFallbackNotice.present(
                StandardFallback(screenCount: 1),
                tourShowing: false,
                defaults: defaults,
                show: record
            )
        }
        StandardFallbackNotice.present(
            StandardFallback(screenCount: 2),
            tourShowing: true,
            defaults: defaults,
            show: record
        )
        #expect(shown == [1])
        #expect(StandardFallbackShown.wasShown(1, in: defaults))
        #expect(StandardFallbackShown.wasShown(2, in: defaults))
    }

    @Test("the tour holds the notice and records the count")
    func tourRecords() {
        let (defaults, name) = makeScratchDefaults()
        defer { TestScratch.remove(name) }
        #expect(!admit(1, tour: true, defaults: defaults))
        #expect(StandardFallbackShown.wasShown(1, in: defaults))
        #expect(!admit(1, defaults: defaults))
    }

    @Test("the window takes the update chrome, above the bars")
    func window() {
        LocalizationManager.shared.select("en")
        let window = StandardFallbackNotice.makeWindow(screenCount: 2) {}
        #expect(window.level == BarPanel.aboveLevel)
        #expect(window.title == "Spaces for 2 Screens")
        #expect(window.styleMask.contains(.closable))
        #expect(window.titleVisibility == .hidden)
        #expect(!window.isOpaque)
        #expect(!window.isReleasedWhenClosed)
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

    @Test("Core's hook reaches the admitted present")
    func wiring() throws {
        let delegate = try source("Sources/KiwiDesk/AppDelegate.swift")
        #expect(delegate.contains("wireStandardFallbackNotice()"))
        let wire = try source(
            "Sources/KiwiDesk/AppDelegate+StandardFallback.swift"
        )
        #expect(wire.contains("core.onStandardFallback={"))
        #expect(wire.contains("StandardFallbackNotice.present("))
        #expect(
            wire.contains(
                "tourShowing:self?.onboardingWindow?.isVisible==true)"
            )
        )
        let notice = try source(
            "Sources/KiwiDesk/StandardNotice/StandardFallbackNotice.swift"
        )
        #expect(
            notice.contains(
                "guardadmit(count:fallback.screenCount,"
                    + "tourShowing:tourShowing,"
            )
        )
        let view = try source(
            "Sources/KiwiDesk/StandardNotice/StandardFallbackView.swift"
        )
        #expect(view.contains(".keyboardShortcut(.defaultAction)"))
        #expect(view.contains(".focused($focused)"))
        #expect(view.contains(".onAppear{focused=true}"))
        #expect(view.contains(".onExitCommand(perform:onOK)"))
        // Text follows the glass, never a fixed ink (owner).
        #expect(view.contains(".foregroundStyle(.primary)"))
        #expect(view.contains(".foregroundStyle(.secondary)"))
        #expect(!view.contains("SettingsTheme.ink"))
    }

    /// Only the two screen-change doors announce; the re-choices
    /// after a profile edit, a delete or a restore stay on the plain
    /// `handleMonitorChange` (#3646).
    @Test("only the screen-change doors announce")
    func announcingDoors() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        let files = try #require(
            FileManager.default.enumerator(atPath: core.path)
        )
        var callers: [String] = []
        for case let path as String in files where path.hasSuffix(".swift") {
            let text = try SourceScan.strippedSource(
                at: core.appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
            let calls =
                text.components(separatedBy: "handleScreenChange(")
                .count - 1
            let defs =
                text.components(
                    separatedBy: "funchandleScreenChange("
                ).count - 1
            for _ in 0..<(calls - defs) {
                callers.append((path as NSString).lastPathComponent)
            }
        }
        #expect(
            callers.sorted() == [
                "KiwiCore+Events.swift", "KiwiCore+MonitorSettle.swift",
            ]
        )
    }

    private func admit(
        _ count: Int,
        tour: Bool = false,
        defaults: UserDefaults
    ) -> Bool {
        StandardFallbackNotice.admit(
            count: count,
            tourShowing: tour,
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
