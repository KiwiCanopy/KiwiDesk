import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A family that is not installed is a Config Issue (#1681),
/// named structurally and derived at the one bar refresh every
/// settings landing passes — so no writer owes it.
@Suite("A missing bar font is a Config Issue", .serialized)
@MainActor
struct BarFontIssueTests {
    private static let missing = "KiwiDesk No Such Family"

    private func hasFontIssue(_ core: KiwiCore) -> Bool {
        core.configIssues.contains { $0.kind.isFontIssue }
    }

    @Test("Setting a missing family files an issue; a fix clears it")
    func missingFamilyIssue() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "kiwishelf.set_font_family",
                args: [.string(Self.missing)]
            ).isSuccess
        )
        #expect(
            core.configIssues.map(\.kind).contains(
                .missingFontFamily(name: Self.missing)
            )
        )
        #expect(core.tiler.settings.kiwishelf.fontFamily == Self.missing)
        #expect(
            core.execute(
                "kiwishelf.set_font_family",
                args: [.string(KiwiShelf.systemMonospacedFontFamily)]
            ).isSuccess
        )
        #expect(!hasFontIssue(core))
    }

    private func profile(_ name: String, family: String) -> Profile {
        var settings = TilingSettings()
        settings.kiwishelf.fontFamily = family
        return Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: settings
        )
    }

    /// A profile apply is a settings landing no verb announces: the
    /// issue follows the profile in and out.
    @Test("The issue follows a profile switch both ways")
    func followsProfileSwitch() throws {
        let core = makeTestCore()
        try core.profiles.save(profile("Broken", family: Self.missing))
        try core.profiles.save(profile("Fine", family: "Menlo"))
        #expect(
            core.execute("load_profile", args: [.string("Broken")])
                .isSuccess
        )
        #expect(hasFontIssue(core))
        #expect(
            core.execute("load_profile", args: [.string("Fine")])
                .isSuccess
        )
        #expect(!hasFontIssue(core))
    }

    /// A font installed while KiwiDesk runs clears the issue at the
    /// observer's call: what `BarFont` read is forgotten first.
    @Test("A font-set change re-reads the family and the issue")
    func fontSetChangeRederives() {
        defer { BarFont.invalidate() }
        let core = makeTestCore()
        core.tiler.settings.kiwishelf.fontFamily = "Menlo"
        // Stands in for Menlo read before it was installed.
        BarFont.cache.faces["Menlo"] = nil
        BarFont.cache.missing.insert("Menlo")
        core.updateBars()
        #expect(hasFontIssue(core))
        core.fontSetDidChange()
        #expect(!hasFontIssue(core))
    }

    /// A posted notification reaches the handler — read off the
    /// issue it re-derives — and after a retire it reaches nothing.
    /// Wired twice first, so a re-wire that skipped retiring the
    /// old token would leak it: the leak keeps firing after the
    /// retire and reds the last clause. `BarFontSeamTests` ▸
    /// `fontSetObserverIsWired` pins the retire-before-add order
    /// in the source as well.
    @Test("The observer delivers, and a retire silences it")
    func observerLifecycle() {
        defer { BarFont.invalidate() }
        let core = makeTestCore()
        defer { core.retireFontSet() }
        core.tiler.settings.kiwishelf.fontFamily = "Menlo"
        core.wireFontSet()
        core.wireFontSet()
        #expect(core.appBars.fontSetObserver != nil)
        BarFont.cache.faces["Menlo"] = nil
        BarFont.cache.missing.insert("Menlo")
        core.updateBars()
        #expect(hasFontIssue(core))
        NotificationCenter.default.post(
            name: NSFont.fontSetChangedNotification,
            object: nil
        )
        #expect(!hasFontIssue(core))
        core.retireFontSet()
        #expect(core.appBars.fontSetObserver == nil)
        BarFont.cache.missing.insert("Menlo")
        BarFont.cache.faces["Menlo"] = nil
        NotificationCenter.default.post(
            name: NSFont.fontSetChangedNotification,
            object: nil
        )
        #expect(BarFont.cache.missing.contains("Menlo"))
    }

    /// A publish that never passes the bar refresh — a load's own
    /// `refreshConfigIssues`, any `setConfigIssues` — still carries
    /// the font issue: the re-derivation is `setConfigIssues`' own.
    @Test("Any publish re-derives the font issue, bars or not")
    func publishRederives() {
        let core = makeTestCore()
        core.tiler.settings.kiwishelf.fontFamily = Self.missing
        core.setConfigIssues([])
        #expect(hasFontIssue(core))
        core.refreshConfigIssues()
        #expect(hasFontIssue(core))
        core.tiler.settings.kiwishelf.fontFamily = "Menlo"
        core.setConfigIssues(core.configIssues)
        #expect(!hasFontIssue(core))
    }
}
