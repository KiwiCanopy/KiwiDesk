import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private let space = SpaceID("1")
private let other = SpaceID("2")
private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let laptop = CGSize(width: 1512, height: 982)

/// A Space of two tiled windows in `mode`, `w1` focused, on one
/// laptop display with its visible bounds pinned.
@MainActor
private func makeCore(mode: String = "bsp") -> KiwiCore {
    let core = makeTestCore()
    let frame = CGRect(origin: .zero, size: laptop)
    core.tiler.visibleBounds = { _ in frame }
    core.state.workspaces.upsertDisplay(
        Display(id: DisplayID(1), name: "A", frame: frame)
    )
    for id in [w1, w2] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: 900_001, appName: "A")
            )
        )
    }
    core.execute("set_mode", args: [.string("1"), .string(mode)])
    core.state.workspaces.assign(space, to: DisplayID(1))
    core.state.workspaces.focus(w1, in: space)
    core.state.apply(.windowFocused(w1))
    return core
}

@MainActor
private func shape(_ core: KiwiCore) -> MaximizeShape? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedShape(of: $0)
    }
}

/// A Space's own Maximize share and anchor (#3090): a binding's own
/// arguments, then the Space's override, then its screen shape's row.
@Suite("Maximize shares per Space (#3090)", .serialized)
@MainActor
struct MaximizeShareSpaceTests {
    @Test("A Space's own share and anchor win over its screen's")
    func overrideWins() {
        let core = makeCore()
        #expect(
            core.execute(
                "maximize.set_share_override",
                args: [.string("1"), .string("height"), .number(0.4)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "maximize.set_anchor_override",
                args: [.string("1"), .string("in_place")]
            ).isSuccess
        )
        core.execute("toggle_maximized", args: [.string("height")])
        #expect(shape(core)?.share == 0.4)
        #expect(shape(core)?.anchor == .inPlace)
    }

    @Test("One axis set alone leaves the other on the screen's row")
    func oneAxisAlone() {
        let core = makeCore()
        core.execute(
            "maximize.set_share_override",
            args: [.string("1"), .string("height"), .number(0.4)]
        )
        core.execute("toggle_maximized", args: [.string("width")])
        #expect(shape(core)?.share == 2.0 / 3)
        #expect(shape(core)?.anchor == .center)
    }

    @Test("A binding's own share and anchor still win")
    func bindingWins() {
        let core = makeCore()
        core.execute(
            "maximize.set_share_override",
            args: [.string("1"), .string("height"), .number(0.4)]
        )
        core.execute(
            "toggle_maximized",
            args: [.string("height"), .number(0.6), .string("center")]
        )
        #expect(shape(core)?.share == 0.6)
    }

    @Test("Another Space's override does not reach this one")
    func otherSpaceIsApart() {
        let core = makeCore()
        core.execute(
            "maximize.set_share_override",
            args: [.string("2"), .string("height"), .number(0.4)]
        )
        core.execute("toggle_maximized", args: [.string("height")])
        #expect(shape(core)?.share == 3.0 / 4)
    }

    @Test("nil clears an axis; an empty entry is dropped")
    func nilClears() {
        let core = makeCore()
        core.execute(
            "maximize.set_share_override",
            args: [.string("1"), .string("width"), .number(0.4)]
        )
        core.execute(
            "maximize.set_share_override",
            args: [.string("1"), .string("width"), .null]
        )
        core.execute(
            "maximize.set_anchor_override",
            args: [.string("1"), .string("center")]
        )
        core.execute(
            "maximize.set_anchor_override",
            args: [.string("1"), .null]
        )
        #expect(core.tiler.settings.maximize.shareOverride[space] == nil)
        #expect(core.tiler.settings.maximize.anchorOverride[space] == nil)
        core.execute(
            "maximize.set_anchor_override",
            args: [.string("1"), .string("center")]
        )
        core.execute("maximize.set_anchor_override", args: [.string("1")])
        #expect(core.tiler.settings.maximize.anchorOverride[space] == nil)
    }

    @Test("The setters refuse a bad share, axis or anchor")
    func refusals() {
        let core = makeCore()
        #expect(
            !core.execute(
                "maximize.set_share_override",
                args: [.string("1"), .string("height"), .number(2)]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "maximize.set_share_override",
                args: [.string("1"), .string("depth"), .number(0.4)]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "maximize.set_anchor_override",
                args: [.string("1"), .string("left")]
            ).isSuccess
        )
        #expect(core.tiler.settings.maximize.shareOverride.isEmpty)
    }

    @Test("resolved(for:) folds the Space's values onto every shape")
    func resolvedFolds() {
        var settings = TilingSettings()
        settings.maximize.setShareOverride(0.4, for: .width, in: space)
        settings.maximize.anchorOverride[space] = .inPlace
        let resolved = settings.resolved(for: space).maximize
        for shape in ScreenShape.allCases {
            #expect(resolved.share(for: .width, on: shape) == 0.4)
            #expect(
                resolved.share(for: .height, on: shape)
                    == MaximizeSettings.defaultHeightShare(shape)
            )
            #expect(resolved.anchor[shape] == .inPlace)
        }
        #expect(resolved.shareOverride.isEmpty)
        #expect(resolved.anchorOverride.isEmpty)
        let apart = settings.resolved(for: other).maximize
        #expect(apart.share(for: .width, on: .laptop) == 2.0 / 3)
    }

    @Test("Each set row counts one toward the Space's overrides")
    func countsOneEach() {
        var settings = TilingSettings()
        settings.maximize.setShareOverride(0.4, for: .height, in: space)
        #expect(settings.spaceOverrideCount(for: space) == 1)
        settings.maximize.setShareOverride(0.4, for: .width, in: space)
        settings.maximize.anchorOverride[space] = .center
        #expect(settings.spaceOverrideCount(for: space) == 3)
        #expect(settings.floatingLiveOverrideCount(for: space) == 3)
    }

    /// An init.lua-only reload keeps the Space declared, so only the
    /// sparse reset in `resetDeclarativeState` drops a value the
    /// script stopped setting.
    @Test("A reload drops values init.lua no longer sets")
    func reloadDropsThem() throws {
        let core = makeTestCore(
            configDirectory: testTemporaryDirectory.appendingPathComponent(
                "kiwi-3090-\(UUID().uuidString)"
            )
        )
        let mine = SpaceID("editor")
        let declare = "KiwiDesk.set_mode(\"editor\", \"bsp\")\n"
        try FileManager.default.createDirectory(
            at: core.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try
            (declare
            + "maximize.set_share_override(\"editor\", "
            + "\"height\", 0.4)\n"
            + "maximize.set_anchor_override(\"editor\", "
            + "\"center\")\n")
            .write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        #expect(core.configIssues.isEmpty, "\(core.configIssues)")
        let set = core.tiler.settings.maximize
        #expect(set.shareOverride[mine]?.height == 0.4)
        #expect(set.anchorOverride[mine] == .center)
        try declare.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(core.state.workspaces[mine] != nil)
        #expect(core.tiler.settings.maximize.shareOverride.isEmpty)
        #expect(core.tiler.settings.maximize.anchorOverride.isEmpty)
    }

    @Test("The keys are share_override and anchor_override")
    func keys() throws {
        var settings = MaximizeSettings()
        settings.setShareOverride(0.4, for: .height, in: space)
        settings.anchorOverride[space] = .inPlace
        let data = try JSONEncoder().encode(settings)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"share_override\""))
        #expect(json.contains("\"anchor_override\""))
        let back = try JSONDecoder().decode(
            MaximizeSettings.self,
            from: data
        )
        #expect(back == settings)
    }

    @Test("A tiled window on Monocle refuses Height and Width")
    func monocleRefusesTiles() {
        let core = makeCore(mode: "monocle")
        for axis in ["height", "width"] {
            #expect(
                !core.execute(
                    "toggle_maximized",
                    args: [.string(axis)]
                ).isSuccess
            )
        }
        #expect(shape(core) == nil)
        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(shape(core)?.axis == nil)
    }

    @Test("A float on Monocle still takes Height and Width")
    func monocleKeepsFloats() {
        for axis in ["height", "width"] {
            let core = makeCore(mode: "monocle")
            core.state.windows.setFloating(w1, true)
            core.retile()
            #expect(
                core.execute(
                    "toggle_maximized",
                    args: [.string(axis)]
                ).isSuccess
            )
            #expect(shape(core)?.axis?.rawValue == axis)
        }
    }
}
