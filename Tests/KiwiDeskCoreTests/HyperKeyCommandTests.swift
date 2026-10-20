import Foundation
import Testing

@testable import KiwiDeskCore

/// A fake `hidutil` and record, standing in for the live host.
@MainActor
private final class FakeHost {
    var mapping: Set<HyperKeyRemap.Pair> = []
    var written: HyperKeyRemap.Pair?
    var answers = true
    var failsSet = false
    var runs = 0

    var host: HyperKeyRemap.Host {
        HyperKeyRemap.Host(
            run: { arguments in
                self.runs += 1
                guard self.answers else { return nil }
                if arguments.contains("--get") { return self.listing }
                if self.failsSet { return nil }
                let json = arguments.last ?? ""
                self.mapping =
                    json.contains("Src")
                    ? [HyperKeyRemap.pair(for: .capsLock)] : []
                return ""
            },
            readWritten: { self.written },
            writeWritten: { self.written = $0 }
        )
    }

    private var listing: String {
        mapping.map {
            """
            1   UserKeyMapping   (
                {
                HIDKeyboardModifierMappingSrc = \($0.source);
                HIDKeyboardModifierMappingDst = \($0.destination);
                }
            )
            """
        }.joined(separator: "\n")
    }
}

/// `set_hyper_key` (#1870): the verb remaps, arms the layer,
/// refuses a mapping it did not write, and `stop()` gives the
/// key back.
@MainActor
@Suite("Hyper key command", .serialized)
struct HyperKeyCommandTests {
    @Test("the verb remaps and arms; stop gives the key back")
    func verbArmsAndStopClears() {
        let core = runningCore()
        let fake = FakeHost()
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("caps_lock")])
        #expect(reply.isSuccess)
        #expect(core.keys.hyperEnabled)
        #expect(core.keys.hyperStatus == .on)
        #expect(fake.written == HyperKeyRemap.pair(for: .capsLock))
        core.retireHyperKey()
        #expect(!core.keys.hyperEnabled)
        #expect(fake.mapping.isEmpty)
        #expect(fake.written == nil)
        #expect(core.appWide.hyperKey == .capsLock)
    }

    @Test("a mapping KiwiDesk did not write is refused")
    func foreignMappingRefuses() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [HyperKeyRemap.pair(for: .capsLock)]
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("caps_lock")])
        #expect(!reply.isSuccess)
        #expect(!core.keys.hyperEnabled)
        #expect(
            core.keys.hyperStatus
                == .refused(
                    HyperForeignRemap(
                        source: .capsLock,
                        destination: .f18,
                        claimable: true
                    )
                )
        )
        #expect(reply.error?.contains("(caps_lock -> f18)") == true)
        // Off takes the no-spawn return and still clears the
        // status the row reads.
        _ = core.execute("set_hyper_key", args: [.string("off")])
        #expect(core.keys.hyperStatus == .off)
        core.retireHyperKey()
        #expect(!fake.mapping.isEmpty)  // never cleared
    }

    @Test("a mapping no key names is refused unnamed")
    func unnamedForeignMapping() {
        let core = runningCore()
        let fake = FakeHost()
        // Caps Lock → Escape: Escape is no `HyperSourceKey`.
        let escape = HyperKeyRemap.usage(0x29)
        let capsLock = HyperKeyRemap.usage(0x39)
        fake.mapping = [.init(source: capsLock, destination: escape)]
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("f13")])
        #expect(core.keys.hyperStatus == .refused(nil))
        #expect(reply.error?.contains("(") == false)
        // Two entries name no one mapping, even when both are keys.
        fake.mapping = [
            HyperKeyRemap.pair(for: .capsLock),
            HyperKeyRemap.pair(for: .f13),
        ]
        _ = core.execute("set_hyper_key", args: [.string("f14")])
        #expect(core.keys.hyperStatus == .refused(nil))
    }

    @Test("a HID usage names a key on the keyboard page alone")
    func usageNamesKey() {
        let usage = HyperKeyRemap.usage(0x39)
        #expect(HyperKeyRemap.key(atUsage: usage) == .capsLock)
        #expect(HyperKeyRemap.key(atUsage: usage & 0xFF) == nil)
        #expect(HyperKeyRemap.key(atUsage: 0xFF_0000_0039) == nil)
        for key in HyperSourceKey.allCases {
            let full = HyperKeyRemap.usage(key.hidUsage)
            #expect(HyperKeyRemap.key(atUsage: full) == key)
        }
    }

    @Test("off clears, and an unknown key is refused by name")
    func offAndUnknown() {
        let core = runningCore()
        let fake = FakeHost()
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        let off = core.execute("set_hyper_key", args: [.string("off")])
        #expect(off.isSuccess)
        #expect(!core.keys.hyperEnabled)
        #expect(fake.mapping.isEmpty)
        let bad = core.execute("set_hyper_key", args: [.string("a")])
        #expect(!bad.isSuccess)
        #expect(bad.error?.contains("caps_lock") == true)
        #expect(bad.error?.contains("off") == true)
    }

    @Test("a silent hidutil leaves Hyper off")
    func failedRemapStaysOff() {
        let core = runningCore()
        let fake = FakeHost()
        fake.answers = false
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("f13")])
        #expect(!reply.isSuccess)
        #expect(!core.keys.hyperEnabled)
    }

    @Test("a stale record dies with an empty mapping")
    func staleRecordIsDropped() {
        let core = runningCore()
        let fake = FakeHost()
        let caps = HyperKeyRemap.pair(for: .capsLock)
        fake.written = caps  // left by a crash; the restart cleared
        core.hyperRemapHost = fake.host
        core.applyHyperKey()
        #expect(fake.written == nil)
        fake.mapping = [caps]  // another tool's, the same shape
        core.applyHyperKey()
        core.retireHyperKey()
        #expect(fake.mapping == [caps])  // never cleared
    }

    @Test("nothing chosen and nothing recorded spawns nothing")
    func idleBootSpawnsNothing() {
        let core = runningCore()
        let fake = FakeHost()
        core.hyperRemapHost = fake.host
        core.applyHyperKey()
        #expect(fake.runs == 0)
        #expect(core.keys.hyperStatus == .off)
    }

    @Test("off with another tool's mapping in place is still off")
    func offBesideForeignIsOff() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [HyperKeyRemap.pair(for: .capsLock)]
        fake.written = HyperKeyRemap.pair(for: .rightCommand)
        core.hyperRemapHost = fake.host
        let off = core.execute("set_hyper_key", args: [.string("off")])
        #expect(off.isSuccess)
        #expect(core.keys.hyperStatus == .off)
        #expect(!fake.mapping.isEmpty)  // never touched
    }

    @Test("a set that did not answer leaves the record true")
    func failedSetSettlesTheRecord() {
        let core = runningCore()
        let fake = FakeHost()
        fake.failsSet = true
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("f13")])
        #expect(!reply.isSuccess)
        #expect(fake.written == nil)  // nothing of ours landed
    }

    @Test("the verb sets the running value and never stores it")
    func verbIsSessionOnly() throws {
        let core = runningCore(directory: true)
        try core.guiConfigStore.save(GuiConfig())
        core.hyperRemapHost = FakeHost().host
        core.setAppWide(persisting: true) { $0.hyperKey = .f13 }
        _ = core.execute("set_hyper_key", args: [.string("f14")])
        #expect(core.appWide.hyperKey == .f14)
        let config = try #require(core.guiConfigStore.load())
        try core.guiConfigStore.save(config)
        #expect(core.guiConfigStore.load()?.appWide?.hyperKey == .f13)
    }

    @Test("a changed value remaps once, after it settles")
    func storedValueApplies() async {
        let core = runningCore()
        let fake = FakeHost()
        core.hyperRemapHost = fake.host
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        core.setAppWide(persisting: false) { $0.hyperKey = .f13 }
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        #expect(fake.runs == 0)  // owed, not yet run
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(core.keys.hyperEnabled)
        #expect(fake.runs == 2)  // one listing, one set: coalesced
        core.setAppWide(persisting: false) { $0.hyperKey = nil }
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(!core.keys.hyperEnabled)
        #expect(fake.mapping.isEmpty)
    }

    @Test("a paused core remaps nothing until start applies it")
    func pausedCoreWaits() {
        let core = makeTestCore()
        let fake = FakeHost()
        core.hyperRemapHost = fake.host
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        #expect(core.deferred.task(for: .hyperRemap) == nil)
        #expect(fake.runs == 0)
        core.applyHyperKey()  // what start() calls
        #expect(core.keys.hyperEnabled)
    }

    @Test("a status change reaches Settings")
    func statusPushes() {
        let core = runningCore()
        core.hyperRemapHost = FakeHost().host
        var pushes = 0
        core.onAppWideChange = { pushes += 1 }
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        let fromLedger = pushes
        core.applyHyperKey()
        #expect(pushes == fromLedger + 1)  // .off → .on
        core.retireHyperKey()
        #expect(pushes == fromLedger + 2)  // a stop moves no ledger
    }
}

/// A core whose event loop reads as running: the remap applies
/// only while KiwiDesk manages windows.
@MainActor
private func runningCore(directory: Bool = false) -> KiwiCore {
    let core =
        directory
        ? makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("hyper-\(UUID().uuidString)")
        )
        : makeTestCore()
    core.eventLoop.isRunning = true
    return core
}
