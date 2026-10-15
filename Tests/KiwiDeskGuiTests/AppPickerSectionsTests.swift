import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shared app picker's two sections (#2103 ruling 27): an app
/// on screen is listed there only, a listed app is left out of
/// both, the search filters both, and "On screen now" is sorted.
struct AppPickerSectionsTests {
    private typealias App = KeybindingCatalog.InstalledApp

    private let installed: [App] = [
        .init(bundleID: "com.apple.Safari", name: "Safari"),
        .init(bundleID: "com.apple.finder", name: "Finder"),
        .init(bundleID: "com.apple.TextEdit", name: "TextEdit"),
    ]

    private let onScreen: [OnScreenApp] = [
        .init(
            key: "com.apple.textedit",
            name: "TextEdit",
            bundleID: "com.apple.TextEdit"
        ),
        .init(key: "sketchybar", name: "sketchybar", bundleID: nil),
    ]

    @Test func onScreenAppIsListedOnce() {
        let lists = AppPickerSections.lists(
            onScreen: onScreen,
            installed: installed,
            exclude: [],
            query: ""
        )
        #expect(
            lists.onScreen.map(\.key)
                == ["sketchybar", "com.apple.textedit"]
        )
        #expect(lists.all.map(\.name) == ["Safari", "Finder"])
    }

    @Test func listedAppsLeaveBothSections() {
        let lists = AppPickerSections.lists(
            onScreen: onScreen,
            installed: installed,
            exclude: ["SketchyBar", "com.apple.safari"],
            query: ""
        )
        #expect(lists.onScreen.map(\.key) == ["com.apple.textedit"])
        #expect(lists.all.map(\.name) == ["Finder"])
    }

    @Test func listedOnScreenAppStaysOutOfAllApps() {
        let lists = AppPickerSections.lists(
            onScreen: onScreen,
            installed: installed,
            exclude: ["com.apple.textedit"],
            query: ""
        )
        #expect(!lists.all.contains { $0.name == "TextEdit" })
        #expect(!lists.onScreen.contains { $0.name == "TextEdit" })
    }

    @Test func searchFiltersBothSections() {
        let lists = AppPickerSections.lists(
            onScreen: onScreen,
            installed: installed,
            exclude: [],
            query: "sketchy"
        )
        #expect(lists.onScreen.map(\.key) == ["sketchybar"])
        #expect(lists.all.isEmpty)
        let none = AppPickerSections.lists(
            onScreen: onScreen,
            installed: installed,
            exclude: [],
            query: "zzz"
        )
        #expect(none.onScreen.isEmpty && none.all.isEmpty)
    }
}
