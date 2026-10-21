import Foundation
import Testing

@testable import KiwiDeskCore

/// An export says why this Mac's `gui.json` cannot go into a
/// backup: written by a newer KiwiDesk, or unreadable.
@Suite("Backup export refusal")
@MainActor
struct BackupExportRefusalTests {
    private func core(gui text: String) throws -> KiwiCore {
        let core = makeTestCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try text.write(
            to: core.guiConfigStore.url,
            atomically: true,
            encoding: .utf8
        )
        return core
    }

    @Test("a newer gui.json is named as newer, with both formats")
    func newerIsNamed() throws {
        let core = try core(gui: #"{"format": 9999}"#)
        #expect(
            core.settingsExportRefusal()
                == .newerSettings(
                    found: 9999,
                    supported: GuiConfig.currentFormat
                )
        )
        let reply = core.execute(
            KiwiCore.exportSetupCommand,
            args: [
                .string(
                    core.configDirectory
                        .appendingPathComponent("b.json").path
                )
            ]
        )
        #expect(reply.error?.contains("newer") == true)
    }

    @Test("a broken gui.json stays unreadable")
    func brokenIsUnreadable() throws {
        let core = try core(gui: "not json")
        #expect(core.settingsExportRefusal() == .unreadableSettings)
    }
}
