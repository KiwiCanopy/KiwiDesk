import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Hyper row's record (#3550): stored like any app-wide row,
/// then re-checked, so the key it already holds heals a remap
/// another tool cleared, and a key a verb set live is kept.
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

    private func runningModel() -> (KiwiCore, Host, SettingsModel) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("hyper-row-\(UUID().uuidString)")
        )
        core.deferred.sleep = { _ in }
        try? core.guiConfigStore.save(GuiConfig())
        let host = Host()
        core.hyperRemapHost = host.host
        core.eventLoop.isRunning = true
        return (core, host, makeTestModel(core: core))
    }

    @Test("recording the key it holds heals with one listing")
    func sameKeyRechecks() async {
        let (core, host, model) = runningModel()
        model.recordHyperKey(.capsLock)
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(core.keys.hyperStatus == .on)
        host.mapping = []  // another tool cleared it
        let gets = host.gets
        model.recordHyperKey(.capsLock)
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.gets == gets + 1)
        #expect(host.mapping == [HyperKeyRemap.pair(for: .capsLock)])
    }

    @Test("another key is one change, read once")
    func otherKeyIsOneChange() async {
        let (core, host, model) = runningModel()
        model.recordHyperKey(.capsLock)
        await core.deferred.task(for: .hyperRemap)?.value
        let gets = host.gets
        model.recordHyperKey(.f13)
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(core.appWide.hyperKey == .f13)
        #expect(host.gets == gets + 1)  // the change and re-check coalesce
    }

    @Test("a key a verb set live is stored when recorded again")
    func verbKeyIsStored() async {
        let (core, _, model) = runningModel()
        _ = core.execute("set_hyper_key", args: [.string("caps_lock")])
        #expect(core.guiConfigStore.load()?.appWide?.hyperKey == nil)
        model.recordHyperKey(.capsLock)
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(core.guiConfigStore.load()?.appWide?.hyperKey == .capsLock)
    }
}
