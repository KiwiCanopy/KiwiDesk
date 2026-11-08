import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private let space = SpaceID("1")
private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// A bsp Space of two tiled windows, `w1` focused, laid out on one
/// display of `screen` points, its visible bounds pinned to the
/// same rect.
@MainActor
private func makeCore(screen: CGSize) -> KiwiCore {
    let core = makeTestCore()
    let frame = CGRect(origin: .zero, size: screen)
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
    core.execute("set_mode", args: [.string("1"), .string("bsp")])
    core.state.workspaces.assign(space, to: DisplayID(1))
    core.state.workspaces.focus(w1, in: space)
    return core
}

@MainActor
private func shape(_ core: KiwiCore) -> MaximizeShape? {
    core.state.workspaces[space].flatMap {
        core.state.maximizedShape(of: $0)
    }
}

private let laptop = CGSize(width: 1512, height: 982)
private let ultrawide = CGSize(width: 3440, height: 1440)

/// The `maximize.*` table (#3062 amendment, owner 2026-11-08): a
/// press takes the share and anchor of the window's screen shape,
/// unless it names its own.
@Suite("Maximize shares per screen shape (#3062)", .serialized)
@MainActor
struct MaximizeShareScreenTests {
    @Test("The ruled defaults, per shape")
    func defaults() {
        let expected: [ScreenShape: (Double, Double, MaximizeAnchor)] = [
            .laptop: (3 / 4, 2 / 3, .center),
            .widescreen: (1 / 2, 1 / 2, .center),
            .ultrawide: (1 / 3, 1 / 2, .inPlace),
            .superUltrawide: (1 / 4, 1 / 2, .inPlace),
            .portrait: (3 / 4, 1 / 2, .center),
        ]
        #expect(Set(expected.keys) == Set(ScreenShape.allCases))
        let settings = MaximizeSettings()
        for (screen, (height, width, anchor)) in expected {
            #expect(settings.share(for: .height, on: screen) == height)
            #expect(settings.share(for: .width, on: screen) == width)
            #expect(settings.anchor[screen] == anchor)
        }
    }

    @Test("Each shape names one class, both ways")
    func shapeClassRoundTrip() {
        for screen in ScreenClass.allCases {
            #expect(ScreenShape(screen).screenClass == screen)
        }
    }

    @Test("A press reads the window's screen shape")
    func pressReadsTheScreen() {
        let core = makeCore(screen: laptop)
        core.execute("toggle_maximized", args: [.string("height")])
        #expect(shape(core)?.share == 3.0 / 4)
        #expect(shape(core)?.anchor == .center)
        core.execute("toggle_maximized", args: [.string("width")])
        #expect(shape(core)?.share == 2.0 / 3)

        let wide = makeCore(screen: ultrawide)
        wide.execute("toggle_maximized", args: [.string("height")])
        #expect(shape(wide)?.share == 1.0 / 3)
        #expect(shape(wide)?.anchor == .inPlace)
    }

    /// A host with no screen has no main screen to read; it passes
    /// vacuously there, as headless CI never is.
    @Test("A Space no screen holds reads the main screen's shape")
    func unplacedReadsTheMainScreen() {
        let core = makeTestCore()
        guard let main = ScreenList.mainOrFirst?.kiwiDisplayID else {
            return
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: main,
                name: "Main",
                frame: CGRect(x: 0, y: 0, width: 1080, height: 1920)
            )
        )
        #expect(core.maximizeScreenShape(of: SpaceID("99")) == .portrait)
        #expect(core.maximizeScreenShape(of: nil) == .portrait)
    }

    @Test("A setter with a shape writes that row alone")
    func setterWritesOneRow() {
        let core = makeCore(screen: laptop)
        core.execute(
            "maximize.set_share",
            args: [.string("height"), .number(0.4), .string("laptop")]
        )
        core.execute(
            "maximize.set_anchor",
            args: [.string("in_place"), .string("laptop")]
        )
        let settings = core.tiler.settings.maximize
        #expect(settings.share(for: .height, on: .laptop) == 0.4)
        #expect(settings.share(for: .height, on: .widescreen) == 0.5)
        #expect(settings.anchor[.laptop] == .inPlace)
        #expect(settings.anchor[.portrait] == .center)
        core.execute("toggle_maximized", args: [.string("height")])
        #expect(shape(core)?.share == 0.4)
        #expect(shape(core)?.anchor == .inPlace)
    }

    @Test("A setter without a shape writes every row")
    func setterWritesEveryRow() {
        let core = makeCore(screen: laptop)
        core.execute(
            "maximize.set_share",
            args: [.string("width"), .number(0.6)]
        )
        core.execute("maximize.set_anchor", args: [.string("center")])
        let settings = core.tiler.settings.maximize
        for screen in ScreenShape.allCases {
            #expect(settings.share(for: .width, on: screen) == 0.6)
            #expect(settings.anchor[screen] == .center)
        }
    }

    @Test("A press's own share wins over the row's")
    func ownShareWins() {
        let core = makeCore(screen: laptop)
        core.execute(
            "toggle_maximized",
            args: [.string("height"), .number(0.6)]
        )
        #expect(shape(core)?.share == 0.6)
    }

    @Test("An unknown shape is refused and writes nothing")
    func unknownShapeRefused() {
        let core = makeCore(screen: laptop)
        let before = core.tiler.settings.maximize
        #expect(
            !core.execute(
                "maximize.set_share",
                args: [.string("height"), .number(0.4), .string("desktop")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "maximize.set_anchor",
                args: [.string("center"), .string("tv")]
            ).isSuccess
        )
        #expect(core.tiler.settings.maximize == before)
    }

    @Test("A stored row round-trips; an absent one keeps its default")
    func coding() throws {
        var settings = MaximizeSettings()
        settings.setShare(0.4, for: .height, on: .portrait)
        settings.anchor[.laptop] = .inPlace
        let data = try JSONEncoder().encode(settings)
        let back = try JSONDecoder().decode(
            MaximizeSettings.self,
            from: data
        )
        #expect(back == settings)
        let sparse = try JSONDecoder().decode(
            MaximizeSettings.self,
            from: Data(
                #"{"share":{"height":{"laptop":0.4}}}"#.utf8
            )
        )
        #expect(sparse.share(for: .height, on: .laptop) == 0.4)
        #expect(sparse.share(for: .height, on: .ultrawide) == 1.0 / 3)
        #expect(sparse.anchor == MaximizeSettings().anchor)
    }
}
