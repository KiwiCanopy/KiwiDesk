import Foundation
import Testing

@testable import KiwiDeskCore

/// What text each bar's driver resolves for a window — the App
/// Bar's items and the Space Bar's front segment. The app name
/// survives as the fallback in the two places a title cannot
/// speak: a collapsed group and an empty title (#160).
@MainActor
private func makeBarCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

private func titledWindow(
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

/// Which text an App Bar item resolves to.
@Suite("App bar item text", .serialized)
@MainActor
struct AppBarItemTextTests {
    private func seeded(
        _ windows: [ManagedWindow]
    ) -> KiwiCore {
        let core = makeBarCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        for window in windows {
            core.state.windows.upsert(window)
            core.state.workspaces.add(window.id, to: "1")
        }
        return core
    }

    private func text(
        _ core: KiwiCore,
        _ group: [UInt32],
        style: AppBarStyle = AppBarStyle()
    ) -> String {
        core.barItem(
            for: group.map(WindowID.init),
            style: style
        ).text
    }

    @Test("A lone window draws its own title")
    func loneWindowDrawsTitle() {
        let core = seeded([titledWindow(1, title: "Downloads")])
        #expect(text(core, [1]) == "Downloads")
    }

    /// Two Finder windows have two titles and the group has
    /// neither, so it names the app instead.
    @Test("A collapsed group draws its app name")
    func groupDrawsAppName() {
        let core = seeded([
            titledWindow(1, title: "Downloads"),
            titledWindow(2, title: "Projects"),
        ])
        #expect(text(core, [1, 2]) == "Finder")
        // ...and each member still draws its own title once the
        // group expands.
        #expect(text(core, [1]) == "Downloads")
        #expect(text(core, [2]) == "Projects")
    }

    /// Lazy-title apps (#160) are tracked before their title
    /// arrives. Without the fallback the bar draws a blank slot.
    @Test("An empty title falls back to the app name")
    func emptyTitleFallsBack() {
        let core = seeded([
            titledWindow(1, app: "Telegram", title: "")
        ])
        #expect(text(core, [1]) == "Telegram")
    }

    @Test("A long title is capped")
    func longTitleIsCapped() {
        let core = seeded([
            titledWindow(
                1,
                app: "zen",
                title:
                    "TanStack Start: Full-Stack React Framework"
            )
        ])
        var style = AppBarStyle()
        style.titleCap = 10
        #expect(text(core, [1], style: style) == "TanStack S…")
    }

    /// The cap is a TITLE cap. An app name reaching an item as
    /// the fallback is short by construction and is not clipped
    /// by a number the user set for titles.
    @Test("The fallback app name is never capped")
    func fallbackNameIsNotCapped() {
        let core = seeded([
            titledWindow(
                1,
                app: "Microsoft PowerPoint",
                title: ""
            )
        ])
        var style = AppBarStyle()
        style.titleCap = 8
        #expect(
            text(core, [1], style: style)
                == "Microsoft PowerPoint"
        )
    }

    /// `name` stays the app's identity whatever is drawn — the
    /// App Font glyph is resolved from it, and it is what the
    /// item announces.
    @Test("The item keeps the app name beside its text")
    func nameSurvivesBesideText() {
        let core = seeded([titledWindow(1, title: "Downloads")])
        let item = core.barItem(for: [WindowID(1)], style: AppBarStyle())
        #expect(item.name == "Finder")
        #expect(item.text == "Downloads")
    }
}

/// The Space Bar's front segment names the focused WINDOW.
@Suite("Space bar front segment title", .serialized)
@MainActor
struct SpaceBarFrontTitleTests {
    private let display = DisplayID(7)

    private func seeded(title: String) -> KiwiCore {
        let core = makeBarCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(
            .windowCreated(
                titledWindow(1, app: "Obsidian", title: title)
            )
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    private func style(cap: Int = 25) -> SpaceBarStyle {
        var style = SpaceBarStyle()
        style.showFrontApp = true
        style.titleCap = cap
        return style
    }

    @Test("The segment carries the focused window's title")
    func segmentCarriesTitle() throws {
        let core = seeded(title: "ToDo — Second_Brain")
        let app = try #require(
            core.frontApp(display: display, style: style())
        )
        #expect(app.title == "ToDo — Second_Brain")
        // The app name rides along: the glyph resolves from it.
        #expect(app.name == "Obsidian")
    }

    @Test("The segment's title is capped")
    func segmentTitleIsCapped() throws {
        let core = seeded(title: "ToDo — Second_Brain — Obsidian")
        let app = try #require(
            core.frontApp(display: display, style: style(cap: 8))
        )
        #expect(app.title == "ToDo — S…")
    }

    /// Nil, not empty: `layoutFrontName` reads `title ?? name`,
    /// so an empty string would draw a blank segment where the
    /// app name belongs.
    @Test("An empty title leaves the segment on the app name")
    func emptyTitleLeavesNil() throws {
        let core = seeded(title: "")
        let app = try #require(
            core.frontApp(display: display, style: style())
        )
        #expect(app.title == nil)
        #expect(app.name == "Obsidian")
    }

    /// Space ITEMS are runs of app glyphs with no text at all,
    /// so they must never carry a title.
    @Test("Space items carry no title")
    func spaceItemsCarryNoTitle() throws {
        let core = seeded(title: "ToDo")
        let items = core.spaceBarItems(
            display: display,
            style: style()
        )
        let apps = items.flatMap(\.apps)
        #expect(!apps.isEmpty)
        #expect(apps.allSatisfy { $0.title == nil })
    }
}
