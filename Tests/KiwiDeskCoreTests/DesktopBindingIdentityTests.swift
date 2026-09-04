import Foundation
import Testing

@testable import KiwiDeskCore

/// A binding follows its Desktop through a renumber (#1147) —
/// the defect this lane exists for.
///
/// The fixture is the measured one (2026-09-03, owner's machine,
/// two rounds): a Desktop inserted before a bound one renumbers
/// every Desktop after it, and unplugging a screen appends the
/// survivors at new numbers. The stamp rides in the Desktop's own
/// record, so the record moves and the number does not.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop binding identity (#1147)", .serialized)
struct DesktopBindingIdentityTests {
    private let stampA = DesktopIdentity(raw: "STAMP-A")
    private let stampB = DesktopIdentity(raw: "STAMP-B")

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-bind-\(UUID().uuidString)"
                )
        )
    }

    private func pin(_ spaces: [NativeSpace], current: UInt64) {
        NativeSpaces.spacesOverride = spaces
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = current
    }

    private func reset() {
        NativeSpaces.spacesOverride = nil
        NativeSpaces.mainDisplayUUIDOverride = nil
        NativeSpaces.activeSpaceIDOverride = nil
    }

    private func desk(
        _ id: UInt64,
        _ identity: DesktopIdentity?,
        current: UInt64
    ) -> NativeSpace {
        NativeSpace(
            id: id,
            displayUUID: "UUID-A",
            isCurrent: id == current,
            identity: identity
        )
    }

    /// Topology A: two stamped Desktops, 1 and 2.
    private func topologyA(current: UInt64) -> [NativeSpace] {
        [
            desk(10, stampA, current: current),
            desk(20, stampB, current: current),
        ]
    }

    /// Topology B: a Desktop inserted at the front, so the desk
    /// that was 2 is now 3 and a NEW desk holds number 2.
    private func topologyB(current: UInt64) -> [NativeSpace] {
        [
            desk(10, stampA, current: current),
            desk(30, DesktopIdentity(raw: "STAMP-NEW"), current: current),
            desk(20, stampB, current: current),
        ]
    }

    /// The whole lane in one clause: bind Desktop 2, insert a
    /// Desktop before it, and the profile still loads on the desk
    /// that was bound — not on whatever now holds number 2.
    @Test("a binding follows its Desktop through a renumber")
    func bindingFollowsTheDesktop() {
        defer { reset() }
        pin(topologyA(current: 20), current: 20)
        let core = makeCore()
        core.execute("save_profile", args: [.string("Work")])
        core.execute("save_profile", args: [.string("Other")])
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Work")]
        )
        // Filed under the DESKTOP, not the number it was
        // declared at.
        #expect(core.desktopBindings[.identity(stampB)] != nil)
        #expect(core.desktopBindings[.number(2)] == nil)

        core.execute("load_profile", args: [.string("Other")])
        // A Desktop appears before it: the bound desk is now 3.
        pin(topologyB(current: 20), current: 20)
        core.handleDesktopChange()
        #expect(core.profiles.currentName == "Work")
        // ...and the row's label followed the desk.
        #expect(
            core.desktopBindings[.identity(stampB)]?.desktop == 3
        )
    }

    /// The mirror, and the silent failure #1147 removes: the desk
    /// that TOOK number 2 must not inherit the binding.
    @Test("the Desktop that took the number is not bound")
    func theNumberDoesNotCarryTheBinding() {
        defer { reset() }
        pin(topologyA(current: 20), current: 20)
        let core = makeCore()
        core.execute("save_profile", args: [.string("Work")])
        core.execute("save_profile", args: [.string("Other")])
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Work")]
        )
        core.execute("load_profile", args: [.string("Other")])
        // Switch to the NEW Desktop now numbered 2 (id 30).
        pin(topologyB(current: 30), current: 30)
        core.handleDesktopChange()
        #expect(core.profiles.currentName == "Other")
    }

    /// A Desktop with no stamp keys by its number, exactly as it
    /// did before this lane — the bridge-absent host's whole
    /// story, and what a declined stamp falls back to.
    @Test("an unstamped Desktop still keys by its number")
    func unstampedKeysByNumber() {
        defer { reset() }
        pin(
            [desk(10, nil, current: 10), desk(20, nil, current: 10)],
            current: 10
        )
        let core = makeCore()
        core.execute("save_profile", args: [.string("Work")])
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Work")]
        )
        #expect(core.desktopBindings[.number(2)] != nil)
    }

    /// A `.number` entry — written by an older build, or while
    /// the Desktop was unstamped — moves to the stamp the first
    /// time the topology can name it. The crossing ENDS: the
    /// number key is gone afterwards.
    @Test("a number entry re-keys to the stamp once")
    func numberEntryRekeys() {
        defer { reset() }
        pin(topologyA(current: 10), current: 10)
        let core = makeCore()
        core.desktopBindings = [
            .number(2): DesktopBinding(profile: "Work", desktop: 2)
        ]
        _ = core.stampedDesktopSnapshot()
        #expect(core.desktopBindings[.number(2)] == nil)
        #expect(
            core.desktopBindings[.identity(stampB)]?.profile
                == "Work"
        )
    }

    /// The move waits for the reading that CONFIRMS the stamp,
    /// never the optimistic one (#884/#889): a stamp the
    /// WindowServer drops would otherwise file the binding under
    /// a key no later reading can name — dormant forever, firing
    /// for nothing. Reverting `reconcileDesktopBindings(in:)` to
    /// the returned snapshot reds this and nothing else (code
    /// review, 2026-09-04).
    @Test("a fresh stamp does not move a binding until it lands")
    func rekeyWaitsForConfirmation() {
        defer { reset() }
        // Desktop 2 carries NO stamp yet, so this call mints one.
        pin(
            [
                desk(10, stampA, current: 10),
                desk(20, nil, current: 10),
            ],
            current: 10
        )
        let core = makeCore()
        core.desktopMemory.writeStamp = { _, _ in true }
        core.desktopBindings = [
            .number(2): DesktopBinding(profile: "Work", desktop: 2)
        ]
        _ = core.stampedDesktopSnapshot()
        // Dispatched, not applied: the binding has not moved.
        #expect(core.desktopBindings[.number(2)] != nil)

        // The WindowServer kept it; the NEXT reading moves it.
        pin(topologyA(current: 10), current: 10)
        _ = core.stampedDesktopSnapshot()
        #expect(core.desktopBindings[.number(2)] == nil)
        #expect(
            core.desktopBindings[.identity(stampB)]?.profile
                == "Work"
        )
    }

    /// The sidecar follows the re-key — and this is the arm no
    /// suite reached before, because `makeTestCore`'s empty
    /// config directory leaves `isGuiManaged` false and skips it
    /// entirely (code review, 2026-09-04).
    ///
    /// It also pins what the follow must NOT do: write back the
    /// live profile state `loadGuiConfig()` overlays. A Desktop
    /// switch is neither of the two ruled profile writes
    /// (profiles.md), so the sidecar's own spaces survive it.
    @Test("the sidecar follows the re-key, and nothing else")
    func sidecarFollowsTheRekey() throws {
        defer { reset() }
        pin(topologyA(current: 10), current: 10)
        let core = makeCore()
        var stored = GuiConfig()
        stored.profileBindings = [
            .number(2): DesktopBinding(profile: "Work", desktop: 2)
        ]
        stored.spaces = [SpaceID("stored-only")]
        try core.guiConfigStore.save(stored)
        core.desktopBindings = stored.profileBindings

        _ = core.stampedDesktopSnapshot()

        let after = try #require(core.guiConfigStore.load())
        #expect(after.profileBindings[.number(2)] == nil)
        #expect(
            after.profileBindings[.identity(stampB)]?.profile
                == "Work"
        )
        // The live space list never entered the file.
        #expect(after.spaces == [SpaceID("stored-only")])
    }

    /// A record whose Desktop is not in the topology is DORMANT:
    /// kept, and still labelled with the number it was last seen
    /// at. Absence is never proof it is gone — the owner's probe
    /// measured a fused Desktop coming back with its stamp.
    @Test("a record whose Desktop is absent is kept, not pruned")
    func absentRecordStaysDormant() {
        defer { reset() }
        pin([desk(10, stampA, current: 10)], current: 10)
        let core = makeCore()
        core.desktopBindings = [
            .identity(stampB): DesktopBinding(
                profile: "Work",
                desktop: 2
            )
        ]
        _ = core.stampedDesktopSnapshot()
        #expect(
            core.desktopBindings[.identity(stampB)]?.desktop == 2
        )
    }
}
