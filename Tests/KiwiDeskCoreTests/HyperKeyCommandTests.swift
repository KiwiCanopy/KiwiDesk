import Foundation
import Testing

@testable import KiwiDeskCore

/// A fake `hidutil` and record, standing in for the live host.
@MainActor
private final class FakeHost {
    var mapping: Set<HyperKeyRemap.Pair> = []
    var written: HyperKeyRemap.Pair?
    var answers = true

    var host: HyperKeyRemap.Host {
        HyperKeyRemap.Host(
            run: { [unowned self] arguments in
                guard answers else { return nil }
                if arguments.contains("--get") { return listing }
                let json = arguments.last ?? ""
                mapping =
                    json.contains("Src")
                    ? [HyperKeyRemap.pair(for: .capsLock)] : []
                return ""
            },
            readWritten: { [unowned self] in written },
            writeWritten: { [unowned self] in written = $0 }
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
        let core = makeTestCore()
        let fake = FakeHost()
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("caps_lock")])
        #expect(reply.isSuccess)
        #expect(core.keys.hyperEnabled)
        #expect(fake.written == HyperKeyRemap.pair(for: .capsLock))
        core.retireHyperKey()
        #expect(!core.keys.hyperEnabled)
        #expect(fake.mapping.isEmpty)
        #expect(fake.written == nil)
        #expect(core.keys.hyperSource == .capsLock)
    }

    @Test("a mapping KiwiDesk did not write is refused")
    func foreignMappingRefuses() {
        let core = makeTestCore()
        let fake = FakeHost()
        fake.mapping = [HyperKeyRemap.pair(for: .capsLock)]
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("caps_lock")])
        #expect(!reply.isSuccess)
        #expect(!core.keys.hyperEnabled)
        core.retireHyperKey()
        #expect(!fake.mapping.isEmpty)  // never cleared
    }

    @Test("off clears, and an unknown key is refused by name")
    func offAndUnknown() {
        let core = makeTestCore()
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
    }

    @Test("a silent hidutil leaves Hyper off")
    func failedRemapStaysOff() {
        let core = makeTestCore()
        let fake = FakeHost()
        fake.answers = false
        core.hyperRemapHost = fake.host
        let reply = core.execute("set_hyper_key", args: [.string("f13")])
        #expect(!reply.isSuccess)
        #expect(!core.keys.hyperEnabled)
    }
}
