import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The gesture list's edits over the draft's sparse map (#3183):
/// pure, no main-actor spend.
@Suite("Gesture list edits (#3183)")
struct GestureListEditsTests {
    private let wheel = GestureKey(.wheel, [.control, .option])

    @Test("a family's directions pre-fill with its one-shot steps")
    func prefill() {
        let arms = GestureListEdits.arms(of: .family(.walk), on: .wheel)
        #expect(arms?[.up]?.lua == GestureFamily.walk.lua(.up))
        #expect(arms?[.down]?.lua == GestureFamily.walk.lua(.down))
        #expect(arms?.count == GestureInput.wheel.directions.count)
    }

    @Test("arms matching a family save as it; one change splits")
    func foldsAndSplits() {
        var arms = GestureListEdits.prefill(.space, on: .wheel)
        #expect(GestureListEdits.folded(arms, on: .wheel) == .family(.space))
        let other = LuaAction(lua: "KiwiDesk.cycle_mode()")
        arms[.up] = other
        guard
            case .split(let saved) = GestureListEdits.folded(
                arms,
                on: .wheel
            )
        else {
            Issue.record("a changed arm should split the row")
            return
        }
        #expect(saved.arms[.up] == other)
        #expect(saved.arms[.down]?.lua == GestureFamily.space.lua(.down))
        arms[.up] = GestureListEdits.prefill(.space, on: .wheel)[.up]
        #expect(GestureListEdits.folded(arms, on: .wheel) == .family(.space))
    }

    @Test("a seed's action reads back; setting it again stores nothing")
    func seedStaysSparse() throws {
        var base = GestureMap()
        let seeded = try #require(
            GestureListEdits.action(
                of: wheel,
                in: base,
                shortcutBase: .standard
            )
        )
        GestureListEdits.set(
            seeded,
            at: wheel,
            in: &base,
            shortcutBase: .standard
        )
        #expect(base[wheel] == nil)
    }

    @Test("removing a seed tombstones it; removing a user row drops it")
    func remove() {
        var base = GestureMap()
        GestureListEdits.remove(wheel, in: &base, shortcutBase: .standard)
        #expect(
            GestureListEdits.action(
                of: wheel,
                in: base,
                shortcutBase: .standard
            ) == nil
        )
        #expect(base[wheel] != nil)
        let mine = GestureKey(.wheel, [.control, .shift])
        GestureListEdits.set(
            .family(.walk),
            at: mine,
            in: &base,
            shortcutBase: .standard
        )
        GestureListEdits.remove(mine, in: &base, shortcutBase: .standard)
        #expect(base[mine] == nil)
    }

    @Test("a re-key onto a held key is refused and changes nothing")
    func rekeyRefusesAClash() {
        var base = GestureMap()
        // A seed holds it (#3281: ⌃⌥ sideways switches Spaces).
        let held = GestureKey(.wheelX, [.control, .option])
        let before = base
        #expect(
            !GestureListEdits.rekey(
                wheel,
                to: held,
                in: &base,
                shortcutBase: .standard
            )
        )
        #expect(base == before)
    }

    @Test("Restore Defaults returns a device's seeds and keeps others")
    func restore() {
        var base = GestureMap()
        GestureListEdits.remove(wheel, in: &base, shortcutBase: .standard)
        let mine = GestureKey(.wheel, [.control, .shift])
        GestureListEdits.set(
            .family(.walk),
            at: mine,
            in: &base,
            shortcutBase: .standard
        )
        #expect(
            GestureListEdits.differsFromDefaults(
                on: .mouse,
                in: base,
                shortcutBase: .standard
            )
        )
        GestureListEdits.restoreDefaults(
            on: .mouse,
            in: &base,
            shortcutBase: .standard
        )
        #expect(
            !GestureListEdits.differsFromDefaults(
                on: .mouse,
                in: base,
                shortcutBase: .standard
            )
        )
        #expect(
            GestureListEdits.action(
                of: mine,
                in: base,
                shortcutBase: .standard
            ) == .family(.walk)
        )
    }

    @Test("rows follow the map: kept, pending, gone and new")
    func reconcile() {
        var base = GestureMap()
        let rows = GestureListEdits.rows(
            in: base,
            on: .mouse,
            shortcutBase: .standard
        )
        .map { GestureListEntry($0) }
        let pending = GestureListEntry(GestureKey(.wheel, [.shift]))
        let dropped = rows[0]
        GestureListEdits.remove(
            dropped.key,
            in: &base,
            shortcutBase: .standard
        )
        let mine = GestureKey(.wheel, [.control, .shift])
        GestureListEdits.set(
            .family(.walk),
            at: mine,
            in: &base,
            shortcutBase: .standard
        )
        let next = GestureListEdits.reconcile(
            rows + [pending],
            pending: [pending.id],
            in: base,
            on: .mouse,
            shortcutBase: .standard
        )
        #expect(!next.contains { $0.id == dropped.id })
        #expect(next.contains { $0.id == pending.id })
        #expect(next.last?.key == mine)
        let kept = rows.dropFirst().map(\.id)
        #expect(next.prefix(kept.count).map(\.id) == Array(kept))
    }

    /// The gesture pop-up's groups (#3281): every input a card can
    /// offer lands under exactly one heading, so an input a front
    /// starts firing never drops out of the menu.
    @Test("every fired input lands in exactly one pop-up group")
    @MainActor func everyInputHasAGroup() {
        for device in [GestureInput.Device.mouse, .trackpad] {
            let offered = GestureListEdits.inputs(on: device)
            #expect(!offered.isEmpty)
            let grouped = GestureListWords.groups(of: offered)
                .flatMap(\.inputs)
            #expect(Set(grouped) == Set(offered))
            #expect(grouped.count == offered.count)
        }
        let fired = GestureInput.allCases.filter(\.isFired)
        let grouped = GestureListWords.groups(of: fired)
            .flatMap(\.inputs)
        #expect(Set(grouped) == Set(fired))
        #expect(grouped.count == fired.count)
    }
}
