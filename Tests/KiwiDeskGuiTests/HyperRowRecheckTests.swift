import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Hyper row's record (#3550): the key already chosen
/// re-checks the remap, which the live values would skip as
/// unchanged, and heals it; another key is a plain change.
@MainActor
@Suite("Hyper row re-check", .serialized)
struct HyperRowRecheckTests {
    @MainActor
    private final class Host {
        var mapping: Set<HyperKeyRemap.Pair> = []
        var written: HyperKeyRemap.Pair?
        var gets = 0

        var host: HyperKeyRemap.Host {
            HyperKeyRemap.Host(
                run: { arguments in
                    if arguments.contains("--get") {
                        self.gets += 1
                        return self.mapping.map {
                            "1 UserKeyMapping (\n{\n"
                                + "HIDKeyboardModifierMappingSrc = "
                                + "\($0.source);\n"
                                + "HIDKeyboardModifierMappingDst = "
                                + "\($0.destination);\n}\n)"
                        }.joined(separator: "\n")
                    }
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
    }

    @Test("the same key re-checks and heals; another key is a change")
    func sameKeyRechecks() async {
        let core = makeTestCore()
        core.deferred.sleep = { _ in }
        let host = Host()
        core.hyperRemapHost = host.host
        core.eventLoop.isRunning = true
        let model = makeTestModel(core: core)
        var changes = 0
        model.recordHyperKey(.capsLock)
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(core.keys.hyperStatus == .on)
        host.mapping = []  // another tool cleared it
        let gets = host.gets
        core.onAppWideChange = { changes += 1 }
        model.recordHyperKey(.capsLock)
        #expect(changes == 0)  // no ledger write: a re-check
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.gets == gets + 1)
        #expect(host.mapping == [HyperKeyRemap.pair(for: .capsLock)])
        model.recordHyperKey(.f13)
        #expect(core.appWide.hyperKey == .f13)
        #expect(changes >= 1)  // the live values moved
    }
}
