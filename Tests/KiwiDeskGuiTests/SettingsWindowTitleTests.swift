import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Settings window is titled after the area it shows (#2059
/// ruling): "Settings" on Home, an area's destination label
/// elsewhere, no app name; only area navigation moves it.
@Suite("Settings window title (#2059)", .serialized)
@MainActor
struct SettingsWindowTitleTests {
    @Test("Home is Settings; an area is its destination label")
    func titleIsTheAreaLabel() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(SettingsWindowTitle.of(nil) == "Settings")
        for destination in SettingsDestination.allCases {
            let title = SettingsWindowTitle.of(destination)
            #expect(title == destination.title)
            #expect(!title.contains("KiwiDesk"))
        }
    }

    @Test("The window follows area navigation and nothing else")
    func windowFollowsTheDestination() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = makeTestModel()
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        SettingsWindowTitle.follow(model, in: window)
        #expect(window.title == "Settings")

        model.destination = .shortcuts
        let shortcuts = SettingsDestination.shortcuts.title
        #expect(window.title == shortcuts)

        // A detail-panel selection and a search reveal request
        // move no area.
        model.nav.shortcutsLayer = "other"
        model.nav.layoutModeTab = .bsp
        model.nav.pendingReveal = SettingsAnchor(
            destination: .general
        )
        #expect(window.title == shortcuts)

        model.destination = nil
        #expect(window.title == "Settings")
    }

    @Test("A language change re-titles the shown area")
    func languageChangeRetitles() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let model = makeTestModel()
        model.destination = .general
        var titles: [String] = []
        model.onWindowTitle = { titles.append($0) }
        model.setLanguage("de")
        #expect(titles.count == 2)
        #expect(titles.last == SettingsDestination.general.title)
        #expect(titles.last != titles.first)
    }
}
