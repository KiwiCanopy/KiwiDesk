import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize's sizes are filed under the arrangement live on their
/// Desktop too (#2921 rulings 5–7): a switch keeps them, a load
/// starts the Desktops shown fresh, a save of a profile ends that
/// profile's everywhere, and a named reset of a Space with no
/// screen resets it on every Desktop.
@Suite("Session sizes per profile (#2921)", .serialized)
@MainActor
struct SessionRatioProfileTests {
    private let space = SpaceID("1")
    private let work = HeldOrigin.Arrangement.profile("Work")
    private let play = HeldOrigin.Arrangement.profile("Play")

    /// "Work" live (`KeepFixture`), with "Play" written beside it.
    private func core() throws -> (KiwiCore, Profile) {
        let core = try KeepFixture.core()
        let other = KeepFixture.profile("Play")
        _ = try core.profiles.write(other)
        #expect(core.liveArrangement == work)
        return (core, other)
    }

    private func show(_ core: KiwiCore, _ desktop: SkyLight.SpaceID) {
        core.desktopMemory.shownSpaces = ["Main": desktop]
        core.desktopMemory.shownUserSpaces = ["Main": true]
    }

    private func stored(
        _ core: KiwiCore,
        _ desktop: SkyLight.SpaceID,
        _ arrangement: HeldOrigin.Arrangement
    ) -> Double? {
        core.desktopMemory.sessionRatios[desktop]?[arrangement]?[space]?
            .splitRatioH
    }

    @Test("a profile switch keeps each profile's sizes")
    func switchKeeps() throws {
        let (core, other) = try core()
        show(core, 10)
        core.writeSplitRatioH(0.7, for: space)
        core.apply(profile: other, cause: .event)
        #expect(core.liveArrangement == play)
        #expect(core.sessionRatios(of: space) == SessionRatios())
        core.writeSplitRatioH(0.3, for: space)
        // The apply's own pass draws the incoming sizes, ahead of
        // the name moving (#1249).
        let door = core.tiler.sessionRatios
        var drawn: [Double?] = []
        core.tiler.sessionRatios = { id in
            let ratios = door(id)
            if id == space { drawn.append(ratios.splitRatioH) }
            return ratios
        }
        let back = try core.profiles.read(name: "Work")
        core.apply(profile: back, cause: .event)
        #expect(!drawn.isEmpty)
        #expect(drawn.allSatisfy { $0 == 0.7 })
        #expect(core.sessionRatios(of: space).splitRatioH == 0.7)
        #expect(stored(core, 10, play) == 0.3)
    }

    @Test("a load starts the Desktops shown fresh, no other")
    func loadClearsTheShownDesktop() throws {
        let (core, _) = try core()
        show(core, 11)
        core.writeSplitRatioH(0.4, for: space)
        show(core, 10)
        core.writeSplitRatioH(0.7, for: space)
        let sized = core.sessionRatios(of: space)
        core.desktopMemory.sessionRatios[10]?[play] = [space: sized]
        KeepFixture.load("Play", core)
        #expect(core.desktopMemory.sessionRatios[10] == nil)
        #expect(stored(core, 11, work) == 0.4)
    }

    @Test("a save of a profile ends its sizes on every Desktop")
    func saveClearsTheProfile() throws {
        let (core, _) = try core()
        for desktop: SkyLight.SpaceID in [10, 11] {
            show(core, desktop)
            core.writeSplitRatioH(0.7, for: space)
        }
        let sized = core.sessionRatios(of: space)
        core.desktopMemory.sessionRatios[11]?[play] = [space: sized]
        core.reapplyIfInEffect("Work")
        #expect(stored(core, 10, work) == nil)
        #expect(stored(core, 11, work) == nil)
        #expect(stored(core, 11, play) == 0.7)
    }

    @Test("a named reset of a Space with no screen is every Desktop's")
    func screenlessResetIsEverywhere() throws {
        let (core, _) = try core()
        let held = SpaceID("7")
        core.state.workspaces.ensureSpace(held)
        try #require(core.state.workspaces.display(of: held) == nil)
        var ratios = SessionRatios()
        ratios.splitRatioH = 0.7
        core.desktopMemory.sessionRatios = [
            10: [work: [held: ratios]],
            11: [play: [held: ratios]],
        ]
        #expect(
            core.execute("reset_layout_sizing", args: [.string("7")])
                .isSuccess
        )
        #expect(core.desktopMemory.sessionRatios.isEmpty)
    }

    @Test("an apply's mode keeps its arrangement's sizes")
    func applyModeKeeps() throws {
        let (core, _) = try core()
        show(core, 10)
        core.writeSplitRatioH(0.7, for: space)
        core.setSpaceMode(space, .stack, keepingSizes: true)
        #expect(stored(core, 10, work) == 0.7)
        core.setSpaceMode(space, .bsp)
        #expect(stored(core, 10, work) == nil)
    }

    @Test("a renumber and a drop reach only the Space's own profile")
    func lifecycleIsScoped() throws {
        let (core, _) = try core()
        var ratios = SessionRatios()
        ratios.splitRatioH = 0.7
        core.desktopMemory.sessionRatios = [
            10: [work: [space: ratios], play: [space: ratios]]
        ]
        core.rekeySessionRatios(space, to: "9", under: work)
        #expect(core.desktopMemory.sessionRatios[10]?[work]?["9"] != nil)
        #expect(core.desktopMemory.sessionRatios[10]?[play]?[space] != nil)
        core.forgetDroppedSessionRatios(of: "9")
        #expect(core.desktopMemory.sessionRatios[10]?[work] == nil)
        #expect(core.desktopMemory.sessionRatios[10]?[play]?[space] != nil)
        // A switch's prune keeps the live profile's own Space too;
        // a load's forgets it.
        core.desktopMemory.sessionRatios[10]?[work] = [space: ratios]
        core.desktopMemory.installing = .init(
            arrangement: work,
            switching: true
        )
        core.forgetDroppedSessionRatios(of: space)
        #expect(core.desktopMemory.sessionRatios[10]?[work]?[space] != nil)
        core.desktopMemory.installing?.switching = false
        core.forgetDroppedSessionRatios(of: space)
        core.desktopMemory.installing = nil
        #expect(core.desktopMemory.sessionRatios[10]?[work] == nil)
    }

    @Test("a held Space's sizes are its origin's, through the retire")
    func heldSpaceIsItsOrigins() throws {
        let (core, _) = try core()
        show(core, 10)
        let held = SpaceID("7")
        core.state.workspaces.ensureSpace(held)
        core.state.heldSpaces[held] = HeldOrigin(
            name: held,
            screen: "gone",
            icon: nil,
            arrangement: play
        )
        core.writeSplitRatioH(0.7, for: held)
        #expect(core.desktopMemory.sessionRatios[10]?[play]?[held] != nil)
        #expect(core.desktopMemory.sessionRatios[10]?[work] == nil)
        // Emptied, it retires and takes its origin's sizes with it.
        #expect(core.retireEmptiedHeldSpaces())
        #expect(core.desktopMemory.sessionRatios.isEmpty)
    }

    @Test("a renamed profile keeps its sizes; a deleted one forgets")
    func renameAndDeleteFollow() throws {
        let (core, _) = try core()
        show(core, 10)
        core.writeSplitRatioH(0.7, for: space)
        try core.renameProfile(from: "Work", to: "Desk")
        #expect(stored(core, 10, .profile("Desk")) == 0.7)
        #expect(stored(core, 10, work) == nil)
        _ = core.execute("delete_profile", args: [.string("Desk")])
        #expect(core.desktopMemory.sessionRatios.isEmpty)
    }

    @Test("a switch's prune keeps the dropped Space's sizes")
    func switchPruneKeeps() throws {
        let (core, other) = try core()
        show(core, 10)
        let extra = SpaceID("5")
        core.state.workspaces.ensureSpace(extra)
        core.writeSplitRatioH(0.7, for: extra)
        // Play's own Space 5 from before, which the prune must not
        // reach either.
        let sized = core.sessionRatios(of: extra)
        core.desktopMemory.sessionRatios[10]?[play] = [extra: sized]
        core.apply(profile: other, cause: .event)
        try #require(core.state.workspaces[extra] == nil)
        #expect(core.desktopMemory.sessionRatios[10]?[work]?[extra] != nil)
        #expect(core.desktopMemory.sessionRatios[10]?[play]?[extra] != nil)
    }
}
