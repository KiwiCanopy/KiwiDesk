import Foundation
import Testing

@testable import KiwiDeskCore

/// A fake `hidutil` and record that counts `--set` calls, so a
/// take-over can be held to writing nothing but the record.
@MainActor
private final class FakeHost {
    var mapping: Set<HyperKeyRemap.Pair> = []
    var written: HyperKeyRemap.Pair?
    var sets = 0
    /// False stands in for a boot session the host cannot read,
    /// where `Host.live` drops the record it was asked to keep.
    var keepsRecord = true

    var host: HyperKeyRemap.Host {
        HyperKeyRemap.Host(
            run: { arguments in
                if arguments.contains("--get") { return self.listing }
                self.sets += 1
                let json = arguments.last ?? ""
                self.mapping =
                    json.contains("Src")
                    ? [HyperKeyRemap.pair(for: .capsLock)] : []
                return ""
            },
            readWritten: { self.written },
            writeWritten: { self.written = self.keepsRecord ? $0 : nil }
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

/// `take_over_hyper_remap` (#2471): a leftover mapping that is
/// exactly KiwiDesk's own entry becomes KiwiDesk's on consent, by
/// writing the ownership record alone; any other mapping keeps
/// the refusal.
@MainActor
@Suite("Hyper key take-over", .serialized)
struct HyperKeyTakeOverTests {
    private static let capsToF18 = HyperKeyRemap.pair(for: .capsLock)

    @Test("the refusal offers only the chosen key's own entry")
    func claimableVerdict() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [Self.capsToF18]
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        #expect(core.keys.hyperStatus == .refused(Self.offer))
        // Caps Lock → F18 while Right ⌘ is chosen is not ours.
        _ = core.execute(
            "set_hyper_key",
            args: [.string("right_command")]
        )
        #expect(
            core.keys.hyperStatus
                == .refused(
                    HyperForeignRemap(source: .capsLock, destination: .f18)
                )
        )
    }

    @Test("a take-over writes the record and runs no set")
    func takeOverWritesTheRecordOnly() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [Self.capsToF18]
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        let reply = core.execute(KiwiCore.takeOverHyperRemapCommand)
        #expect(reply.isSuccess)
        #expect(core.keys.hyperStatus == .on)
        #expect(core.keys.hyperEnabled)
        #expect(fake.written == Self.capsToF18)
        #expect(fake.sets == 0)
        #expect(fake.mapping == [Self.capsToF18])
    }

    @Test("a mapping changed before the click is still refused")
    func changedMappingRefuses() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [Self.capsToF18]
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        let other = HyperKeyRemap.pair(for: .f13)
        fake.mapping = [other]
        let reply = core.execute(KiwiCore.takeOverHyperRemapCommand)
        #expect(!reply.isSuccess)
        #expect(fake.written == nil)
        #expect(fake.sets == 0)
        #expect(fake.mapping == [other])
        guard case .refused = core.keys.hyperStatus else {
            Issue.record("expected a refusal")
            return
        }
    }

    @Test("our entry beside another is never taken over")
    func ourEntryBesideAnotherRefuses() {
        let core = runningCore()
        let fake = FakeHost()
        let both = [Self.capsToF18, HyperKeyRemap.pair(for: .f13)]
        fake.mapping = Set(both)
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        let reply = core.execute(KiwiCore.takeOverHyperRemapCommand)
        #expect(!reply.isSuccess)
        #expect(fake.written == nil)
        #expect(fake.sets == 0)
    }

    @Test("a record the host cannot keep fails the take-over")
    func unkeptRecordFails() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [Self.capsToF18]
        fake.keepsRecord = false
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        let reply = core.execute(KiwiCore.takeOverHyperRemapCommand)
        #expect(!reply.isSuccess)
        #expect(core.keys.hyperStatus == .failed)
        #expect(!core.keys.hyperEnabled)
    }

    @Test("a taken-over remap is cleared at stop")
    func stopClearsTheTakenOverRemap() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [Self.capsToF18]
        core.hyperRemapHost = fake.host
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        _ = core.execute(KiwiCore.takeOverHyperRemapCommand)
        core.retireHyperKey()
        #expect(fake.mapping.isEmpty)
        #expect(fake.written == nil)
    }

    @Test("no chosen key or a paused core refuses the take-over")
    func refusals() {
        let core = runningCore()
        let fake = FakeHost()
        fake.mapping = [Self.capsToF18]
        core.hyperRemapHost = fake.host
        #expect(!core.execute(KiwiCore.takeOverHyperRemapCommand).isSuccess)
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        core.eventLoop.isRunning = false
        #expect(!core.execute(KiwiCore.takeOverHyperRemapCommand).isSuccess)
        #expect(fake.written == nil)
    }

    @Test("the verb never reaches init.lua and reads destructive")
    func registers() {
        let name = KiwiCore.takeOverHyperRemapCommand
        #expect(APIReference.cliOnly.contains(name))
        #expect(APIReference.destructive.contains(name))
    }

    private static let offer = HyperForeignRemap(
        source: .capsLock,
        destination: .f18,
        claimable: true
    )
}

/// A core whose event loop reads as running: the remap applies
/// only while KiwiDesk manages windows.
@MainActor
private func runningCore() -> KiwiCore {
    let core = makeTestCore()
    core.eventLoop.isRunning = true
    return core
}
