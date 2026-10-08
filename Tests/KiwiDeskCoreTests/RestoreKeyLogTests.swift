import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The #1385 step 2 measurement (`RestoreKeyLog`): one line per
/// window at the autosave and at boot adoption, read through the
/// core's `onLog` seam; an autosave that repeats the last logged
/// batch logs nothing; and without the opt-in neither site logs.
/// Removed with the measurement.
@Suite("Restore key measurement (#1385)", .serialized)
@MainActor
struct RestoreKeyLogTests {
    /// Two Editor windows on Space 1, a third on Space 2, and a
    /// Viewer window between the first two in Space 1's order.
    static func file(_ core: KiwiCore) {
        let windows: [(UInt32, String, String, SpaceID)] = [
            (11, "com.example.editor", "a.txt", "1"),
            (12, "com.example.viewer", "photo", "1"),
            (13, "com.example.editor", "say \"hi\"", "1"),
            (14, "com.example.editor", "c.txt", "2"),
        ]
        for (raw, bundle, title, space) in windows {
            core.state.workspaces.ensureSpace(space)
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 100,
                        appName: "App",
                        appBundleID: bundle,
                        title: title
                    )
                )
            )
            core.state.workspaces.add(WindowID(raw), to: space)
        }
    }

    static func expected(_ phase: String) -> [String] {
        let p = "restore-key: phase=\(phase)"
        return [
            "\(p) count=4",
            "\(p) space=1 rank=0 appRank=0 window=w11"
                + " app=com.example.editor title=\"a.txt\"",
            "\(p) space=1 rank=0 appRank=0 window=w12"
                + " app=com.example.viewer title=\"photo\"",
            "\(p) space=1 rank=1 appRank=1 window=w13"
                + " app=com.example.editor title=\"say \\\"hi\\\"\"",
            "\(p) space=2 rank=0 appRank=2 window=w14"
                + " app=com.example.editor title=\"c.txt\"",
        ]
    }

    static func keyLines(_ lines: [String]) -> [String] {
        lines.filter { $0.hasPrefix(RestoreKeyLog.prefix) }
    }

    static func autosaveCore(optedIn: Bool = true) -> (KiwiCore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-rkey-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: dir)
        core.crash.captureState = { [weak core] in
            core?.state.snapshot()
        }
        core.crash.restoreKeys.isOptedIn = { optedIn }
        return (core, dir)
    }

    static func bootCore(optedIn: Bool = true) throws -> KiwiCore {
        let core = try #require(F.makeCore())
        core.crash.restoreKeys.isOptedIn = { optedIn }
        return core
    }

    @Test(
        "Not opted in, neither site logs",
        .enabled(if: NSScreen.main != nil)
    )
    func offByDefaultLogsNothing() throws {
        let (core, dir) = Self.autosaveCore(optedIn: false)
        defer { try? FileManager.default.removeItem(at: dir) }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        core.crash.autosave()
        #expect(Self.keyLines(lines).isEmpty)

        let boot = try Self.bootCore(optedIn: false)
        boot.onLog = { lines.append($0) }
        Self.file(boot)
        boot.arrangeBootDesk(session: nil)
        #expect(Self.keyLines(lines).isEmpty)
    }

    @Test("An autosave logs each window's key")
    func autosaveLogsEachWindow() {
        let (core, dir) = Self.autosaveCore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        core.crash.autosave()
        #expect(Self.keyLines(lines) == Self.expected("autosave"))
    }

    @Test("An unchanged autosave logs nothing; a retitle logs again")
    func unchangedAutosaveIsSilent() {
        let (core, dir) = Self.autosaveCore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        core.crash.autosave()
        lines.removeAll()
        core.crash.autosave()
        #expect(Self.keyLines(lines).isEmpty)
        core.state.apply(.windowTitleChanged(WindowID(14), "d.txt"))
        core.crash.autosave()
        #expect(
            Self.keyLines(lines).last
                == "restore-key: phase=autosave space=2 rank=0"
                + " appRank=2 window=w14 app=com.example.editor"
                + " title=\"d.txt\""
        )
    }

    @Test(
        "Boot adoption logs each window's key",
        .enabled(if: NSScreen.main != nil)
    )
    func bootLogsEachWindow() throws {
        let core = try Self.bootCore()
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        core.arrangeBootDesk(session: nil)
        #expect(Self.keyLines(lines) == Self.expected("boot"))
    }
}
