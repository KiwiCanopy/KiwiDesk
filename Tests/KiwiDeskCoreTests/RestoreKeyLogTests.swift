import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// The #1385 step 2 measurement (`RestoreKeyLog`): one line per
/// window at the autosave and at boot adoption, read through the
/// core's `onLog` seam; an autosave that repeats the last logged
/// batch logs nothing; and opted out, neither site logs.
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

    @Test("Opted out, the autosave logs no key")
    func optedOutAutosaveIsGated() {
        let (core, dir) = Self.autosaveCore(optedIn: false)
        defer { try? FileManager.default.removeItem(at: dir) }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        core.crash.autosave()
        #expect(Self.keyLines(lines).isEmpty)
    }

    @Test(
        "Opted out, boot adoption logs no key",
        .enabled(if: NSScreen.main != nil)
    )
    func optedOutBootIsGated() throws {
        let core = try Self.bootCore(optedIn: false)
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        core.arrangeBootDesk(session: nil)
        #expect(Self.keyLines(lines).isEmpty)
    }

    /// A recovery wired as bootstrap wires the core's, over
    /// `directory`, opted in.
    static func recovery(
        at directory: URL,
        for core: KiwiCore
    ) -> CrashRecovery {
        let recovery = CrashRecovery(directory: directory)
        recovery.captureState = { [weak core] in
            core?.state.snapshot()
        }
        recovery.restoreKeys.isOptedIn = { true }
        recovery.onAutosaved = { [weak core, weak recovery] in
            if let core { recovery?.restoreKeys.autosave(core) }
        }
        return recovery
    }

    @Test("An autosave whose write fails logs no key")
    func failedWriteLogsNothing() throws {
        let (core, dir) = Self.autosaveCore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        Self.file(core)
        // A regular file where the directory should be: neither
        // the directory nor the snapshot can be written.
        let blocker = dir.appendingPathComponent("blocker")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try Data().write(to: blocker)
        Self.recovery(at: blocker, for: core).autosave()
        #expect(Self.keyLines(lines).isEmpty)
        // The control: the same wiring over a writable directory
        // logs, so the silence above is the failed write's.
        let writable = dir.appendingPathComponent("writable")
        Self.recovery(at: writable, for: core).autosave()
        #expect(Self.keyLines(lines) == Self.expected("autosave"))
    }

    @Test("A window with no bundle id, filed in no Space")
    func unfiledWindowWithoutBundle() {
        let (core, dir) = Self.autosaveCore()
        defer { try? FileManager.default.removeItem(at: dir) }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(21), pid: 7, appName: "Loose")
            )
        )
        core.state.workspaces.remove(WindowID(21))
        core.crash.autosave()
        #expect(
            Self.keyLines(lines) == [
                "restore-key: phase=autosave count=1",
                "restore-key: phase=autosave space=- rank=0 appRank=0"
                    + " window=w21 app=?Loose title=\"\"",
            ]
        )
    }

    @Test(
        "Boot logs the scan's Space, before the session re-files it",
        .enabled(if: NSScreen.main != nil)
    )
    func bootLogsTheScanBeforeTheRestore() throws {
        let window = F.Window(
            id: WindowID(31),
            space: F.hidden,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        let a = try #require(F.processA([window]))
        let session = try F.crossed(a.sessionSnapshot())
        let core = try Self.bootCore()
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        core.state.apply(.windowCreated(F.managed(window)))
        core.state.workspaces.add(window.id, to: F.shown)
        core.arrangeBootDesk(session: session)
        #expect(
            Self.keyLines(lines) == [
                "restore-key: phase=boot count=1",
                "restore-key: phase=boot space=1 rank=0 appRank=0"
                    + " window=w31 app=?App31 title=\"\"",
            ]
        )
        // The restore did re-file it, so the line above is the
        // scan's filing and not the session's.
        #expect(
            core.state.workspaces[F.hidden]?.windows == [window.id]
        )
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
