import AppKit
import Foundation

@testable import KiwiDeskCore

// Shared fixtures for the three bar-title suites
// (`BarTitleRefreshTests`, `BarTitleRefreshOutputTests`,
// `BarTitleTextTests`). Split out at the §2.1 ceiling, and to
// stop the third copy of `makeBarCore` from appearing — the
// `AppBarFixtures.swift` / `SpaceBarFixtures.swift` arrangement.

@MainActor
func makeBarCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

func titledWindow(
    _ id: UInt32,
    app: String = "Finder",
    title: String
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: title,
        isFloating: false
    )
}

// MARK: - Painted bars

// The title-refresh gate reads what the managers PAINTED, so its
// fixtures hand the managers a bar directly rather than seeding
// state and hoping a driver builds one. `sync` is the drivers'
// own entry point, so nothing here bypasses production code — it
// starts one step later, with no screen to match and no
// WindowServer to ask.

let barTitleDisplay = DisplayID(7)
let barTitleStrip = CGRect(x: 0, y: 0, width: 1440, height: 28)

func appBarItem(
    _ id: UInt32,
    text: String,
    count: Int = 1
) -> AppBarOverlay.Item {
    AppBarOverlay.Item(
        id: WindowID(id),
        text: text,
        icon: nil,
        count: count
    )
}

@MainActor
func paintedAppBar(
    content: AppBarStyle.Content = .iconAndTitle,
    edge: AppBarEdge = .top,
    items: [AppBarOverlay.Item]
) -> AppBarManager.Bar {
    var style = AppBarStyle()
    style.content = content
    style.edge = edge
    return AppBarManager.Bar(
        display: barTitleDisplay,
        space: SpaceID("1"),
        items: items,
        activeIndex: 0,
        strip: barTitleStrip,
        style: style
    )
}

@MainActor
func paintedSpaceBar(
    edge: AppBarEdge = .top,
    front: WindowID?
) -> SpaceBarManager.Bar {
    var style = SpaceBarStyle()
    style.edge = edge
    style.showFrontApp = front != nil
    return SpaceBarManager.Bar(
        display: barTitleDisplay,
        items: [
            SpaceBarOverlay.Item(
                space: SpaceID("1"),
                spaceGlyph: .text("1", tinted: true),
                apps: [],
                active: true,
                overflow: 0,
                focusInOverflow: false
            )
        ],
        frontApp: front.map { _ in
            SpaceBarItemView.App(
                name: "Finder",
                icon: nil,
                glyph: nil,
                focused: true,
                count: 1
            )
        },
        frontWindow: front,
        strip: barTitleStrip,
        style: style,
        stateMarkColors: StateMarkColors(
            sticky: "#ffffff",
            floating: "#ffffff"
        )
    )
}
