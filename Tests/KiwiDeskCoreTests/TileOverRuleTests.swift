import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A Tile overrules a float rule for as long as the window lives
/// (#2975): the rule decides how a window starts, a Tile keeps that
/// window tiled through a hide, a re-judge and a recheck, a Float
/// ends it, and a close, an exit or a reason that refuses a Tile
/// end it too. Every event goes through `KiwiCore.handle`, where
/// the record's one reader sits.
@Suite("Tile overrules a float rule (#2975)", .serialized)
@MainActor
struct TileOverRuleTests {
    private let id = WindowID(1)
    private let pid: pid_t = 900_975

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-tile-over-rule-\(UUID().uuidString)"
                )
        )
    }

    /// Adopts window 1 as `track` would: the cached verdict first,
    /// then the arrival with the flag it gives.
    private func arrive(_ core: KiwiCore, _ verdict: FloatVerdict) {
        var window = ManagedWindow(
            id: id,
            pid: pid,
            appName: "App",
            title: "Doc"
        )
        window.isFloating = verdict.floats
        core.eventLoop.detectedFloating[id] = verdict
        core.handle(.windowCreated(window))
    }

    /// A recheck reading `reason`, its events handled by the core.
    private func recheck(_ core: KiwiCore, _ reason: AutoFloatReason?) {
        var events: [KiwiEvent] = []
        core.eventLoop.detectedFullscreen[id] = false
        core.eventLoop.onEvent = { events.append($0) }
        core.eventLoop.recheckFloat(
            id: id,
            pid: pid,
            app: AppRef(pid: pid),
            reading: TrackedReading(
                fullscreen: false,
                subrole: "",
                frame: .zero,
                autoReason: reason,
                traits: nil
            )
        )
        for event in events { core.handle(event) }
    }

    private func floats(_ core: KiwiCore) -> Bool? {
        core.state.windows[id]?.isFloating
    }

    /// Floats window 1 by a rule and tiles it.
    private func tiledOverRule() -> KiwiCore {
        let core = makeCore()
        arrive(core, .floats(.rule))
        #expect(floats(core) == true)
        #expect(core.execute("make_tiled").isSuccess)
        return core
    }

    @Test("a Tile tiles a window a rule floats, with no user record")
    func tileTiles() {
        let core = tiledOverRule()
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
        #expect(core.state.userFloated.isEmpty)
        // The verdict stays the rule's: detection is not re-judged.
        #expect(core.tileRefusal(of: id) == .rule)
        #expect(core.tileRefused(id) == nil)
    }

    @Test("the record survives a hide and the re-adoption")
    func hideKeeps() {
        let core = tiledOverRule()
        core.handle(.windowHidden(id))
        #expect(core.state.tiledOverRule[id] == pid)
        arrive(core, .floats(.rule))
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
    }

    /// A changed guess forgets the verdict (`rejudgeGuesses`), and
    /// the next recheck reports the rule's float again.
    @Test("a forgotten verdict's recheck keeps the Tile")
    func rejudgeKeeps() {
        let core = tiledOverRule()
        core.eventLoop.detectedFloating[id] = nil
        recheck(core, .rule)
        #expect(core.eventLoop.detectedFloating[id] == .floats(.rule))
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
    }

    @Test("a Float ends the Tile and records no user float")
    func floatEnds() {
        let core = tiledOverRule()
        #expect(core.execute("make_floating").isSuccess)
        #expect(floats(core) == true)
        #expect(!core.state.tilesOverRule(id))
        #expect(core.state.userFloated.isEmpty)
        // So the rule removed tiles the window.
        recheck(core, nil)
        #expect(floats(core) == false)
    }

    /// A hand float ends the record wherever it is written, so the
    /// two never stand together: the rule removed, a Float, the
    /// rule back — the float is the rule's again, never a Tile.
    @Test("a hand float ends a Tile over a rule")
    func handFloatEnds() {
        let core = tiledOverRule()
        recheck(core, nil)
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.userFloated == [id])
        #expect(core.state.tiledOverRule.isEmpty)
        recheck(core, .rule)
        #expect(floats(core) == true)
        #expect(core.state.userFloated.isEmpty)
        core.handle(.windowHidden(id))
        arrive(core, .floats(.rule))
        #expect(floats(core) == true)
    }

    /// The reopen memory of a same-titled window floated by hand
    /// never floats a window tiled over its rule: consumed at the
    /// re-adoption and at a retitle alike.
    @Test("the reopen memory never floats a Tile over a rule")
    func reopenMemoryKeepsTheTile() {
        let core = tiledOverRule()
        let twin = ManagedWindow(
            id: id,
            pid: pid,
            appName: "App",
            title: "Doc"
        )
        let identity = StateCoordinator.WindowIdentity(of: twin)
        core.state.rememberedFloating.insert(identity)
        core.handle(.windowHidden(id))
        arrive(core, .floats(.rule))
        #expect(floats(core) == false)
        #expect(core.state.userFloated.isEmpty)
        #expect(core.state.rememberedFloating.isEmpty)
        let retitled = StateCoordinator.WindowIdentity(
            of: ManagedWindow(
                id: id,
                pid: pid,
                appName: "App",
                title: "New"
            )
        )
        core.state.rememberedFloating.insert(retitled)
        core.handle(.windowTitleChanged(id, "New"))
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
        #expect(core.state.rememberedFloating.isEmpty)
    }

    @Test("a toggle flips a Tile over a rule both ways")
    func toggleFlips() {
        let core = tiledOverRule()
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(floats(core) == true)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
    }

    /// A rule's Float without a Tile has nothing to end.
    @Test("a Float of a rule-floated window changes nothing")
    func floatOfRuleFloatIsNoOp() {
        let core = makeCore()
        arrive(core, .floats(.rule))
        #expect(core.execute("make_floating").isSuccess)
        #expect(floats(core) == true)
        #expect(core.state.userFloated.isEmpty)
        #expect(core.state.tiledOverRule.isEmpty)
    }

    /// A rule turning into a dialog's float is no longer the
    /// rule's: the reason change is emitted and ends the record.
    @Test("a reason that refuses a Tile ends it and floats")
    func refusingReasonEnds() {
        let core = tiledOverRule()
        recheck(core, .panel)
        #expect(floats(core) == true)
        #expect(!core.state.tilesOverRule(id))
        #expect(core.tileRefused(id) == .panel)
    }

    /// #2572: Brave lifts its main window to 999. Over a record the
    /// latch keeps the rule's verdict, so the lift floats nothing
    /// and the record survives it.
    @Test("a raised layer over a Tile keeps it tiled")
    func raisedLayerKeeps() {
        let core = tiledOverRule()
        recheck(core, .raisedLayer)
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
        #expect(core.eventLoop.detectedFloating[id] == .floats(.rule))
        // A Float there is the rule's, never a hand float.
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.userFloated.isEmpty)
        #expect(core.execute("make_tiled").isSuccess)
        // A forgotten verdict lifted keeps the rule's too.
        core.eventLoop.detectedFloating[id] = nil
        recheck(core, .raisedLayer)
        #expect(core.eventLoop.detectedFloating[id] == .floats(.rule))
        // Its fall back to layer 0 is the rule's float again.
        recheck(core, .rule)
        #expect(core.eventLoop.detectedFloating[id] == .floats(.rule))
        #expect(floats(core) == false)
        #expect(core.state.tilesOverRule(id))
    }

    /// Without a record the latch is unchanged: a window the rule
    /// floats keeps floating on the layer's reading.
    @Test("a raised layer without a Tile keeps the latch's verdict")
    func raisedLayerControl() {
        let core = makeCore()
        arrive(core, .floats(.rule))
        recheck(core, .raisedLayer)
        #expect(core.eventLoop.detectedFloating[id] == .floats(.raisedLayer))
    }

    @Test("a close ends the record, a minimize keeps it")
    func closeEnds() {
        let core = tiledOverRule()
        core.handle(.windowDestroyed(id, wasMinimized: true))
        #expect(core.state.tiledOverRule[id] != nil)
        arrive(core, .floats(.rule))
        #expect(floats(core) == false)
        core.handle(.windowDestroyed(id, wasMinimized: false))
        #expect(core.state.tiledOverRule[id] == nil)
        // A reopen obeys the rule.
        arrive(core, .floats(.rule))
        #expect(floats(core) == true)
    }

    @Test("an app's exit and an away retirement end the record")
    func exitAndAwayEnd() {
        let exited = tiledOverRule()
        exited.state.apply(.windowHidden(id))
        exited.state.apply(.appTerminated(pid: pid))
        #expect(exited.state.tiledOverRule.isEmpty)
        let away = tiledOverRule()
        away.state.forgetAway(id)
        #expect(away.state.tiledOverRule.isEmpty)
    }

    @Test("the record follows a native-tab re-key")
    func rekeyFollows() {
        let core = tiledOverRule()
        let new = WindowID(9)
        core.state.apply(.windowRekeyed(id, new))
        #expect(core.state.tiledOverRule[new] == pid)
        #expect(core.state.tiledOverRule[id] == nil)
    }

    /// A record naming another process is not this window's: an id
    /// recycled after the app it named has gone floats by its rule.
    @Test("a record for another pid holds nothing")
    func otherPidHoldsNothing() {
        let core = tiledOverRule()
        core.state.tiledOverRule[id] = pid + 1
        core.handle(.windowHidden(id))
        arrive(core, .floats(.rule))
        #expect(floats(core) == true)
        #expect(core.state.tiledOverRule.isEmpty)
    }

    @Test("pocketing ends the record")
    func pocketEnds() {
        let core = tiledOverRule()
        let marked = core.state.markPocketWindow(id)
        #expect(marked)
        #expect(core.state.tiledOverRule.isEmpty)
    }

    @Test("only a rule's float lets a Tile through, and names it")
    func ruleNamesTheTile() {
        #expect(AutoFloatReason.rule.escapes.first == "make_tiled")
        #expect(!AutoFloatReason.rule.refusesTile)
        for reason: AutoFloatReason in [
            .panel, .raisedLayer, .accessoryApp, .fixedSize, .pocket,
        ] {
            #expect(reason.refusesTile)
        }
    }
}
