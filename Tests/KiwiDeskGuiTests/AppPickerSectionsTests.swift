import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shared app picker's two sections (#2103 ruling 27): an open
/// app is listed there only, a listed app is left out of both,
/// the search filters both, and "Open apps" is sorted.
struct AppPickerSectionsTests {
    private typealias App = KeybindingCatalog.InstalledApp

    private let installed: [App] = [
        .init(bundleID: "com.apple.Safari", name: "Safari"),
        .init(bundleID: "com.apple.finder", name: "Finder"),
        .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
    ]

    private let openApps: [OpenApp] = [
        .init(
            app: AppRef(bundleID: "com.apple.TextEdit", name: "TextEdit"),
            name: "TextEdit"
        ),
        .init(
            app: AppRef(bundleID: nil, name: "sketchybar"),
            name: "sketchybar"
        ),
    ]

    @Test func openAppIsListedOnce() {
        let lists = AppPickerSections.lists(
            openApps: openApps,
            installed: installed,
            exclude: [],
            query: ""
        )
        #expect(
            lists.openApps.map(\.key)
                == ["sketchybar", "com.apple.textedit"]
        )
        #expect(lists.all.map(\.name) == ["Safari", "Finder"])
    }

    @Test func listedAppsLeaveBothSections() {
        let lists = AppPickerSections.lists(
            openApps: openApps,
            installed: installed,
            exclude: ["SketchyBar", "com.apple.safari"],
            query: ""
        )
        #expect(lists.openApps.map(\.key) == ["com.apple.textedit"])
        #expect(lists.all.map(\.name) == ["Finder"])
    }

    @Test func listedOpenAppStaysOutOfAllApps() {
        let lists = AppPickerSections.lists(
            openApps: openApps,
            installed: installed,
            exclude: ["com.apple.textedit"],
            query: ""
        )
        #expect(!lists.all.contains { $0.name == "TextEdit" })
        #expect(!lists.openApps.contains { $0.name == "TextEdit" })
    }

    @Test func searchFiltersBothSections() {
        let lists = AppPickerSections.lists(
            openApps: openApps,
            installed: installed,
            exclude: [],
            query: "sketchy"
        )
        #expect(lists.openApps.map(\.key) == ["sketchybar"])
        #expect(lists.all.isEmpty)
        let none = AppPickerSections.lists(
            openApps: openApps,
            installed: installed,
            exclude: [],
            query: "zzz"
        )
        #expect(none.openApps.isEmpty && none.all.isEmpty)
    }
}
