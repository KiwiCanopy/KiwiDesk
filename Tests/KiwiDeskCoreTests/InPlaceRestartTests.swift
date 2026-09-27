import Foundation
import Security
import Testing

@testable import KiwiDeskCore

/// The in-place restart intent (#930): announced, never
/// inferred; consumed by the next stop; honoured only within its
/// bound; and for `service restart` only when the program launchd
/// will start passes the identity gate. The clock is pinned per
/// test (tests.md, #1456).
@Suite("In-place restart intent (#930)", .serialized)
@MainActor
struct InPlaceRestartTests {
    /// The on-disk path of the running test process, which
    /// satisfies its own requirement by construction.
    nonisolated static var selfPath: URL? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var path: CFURL?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
            SecCodeCopyStaticCode(code, [], &staticCode)
                == errSecSuccess,
            let staticCode,
            SecCodeCopyPath(staticCode, [], &path) == errSecSuccess
        else { return nil }
        return path as URL?
    }

    /// Whether the test process is validly signed — read without
    /// `CodeIdentity`, so a regression there reds the tests this
    /// gates rather than skipping them.
    nonisolated static var selfIsSigned: Bool {
        var staticCode: SecStaticCode?
        guard let path = selfPath,
            SecStaticCodeCreateWithPath(path as CFURL, [], &staticCode)
                == errSecSuccess,
            let staticCode
        else { return false }
        return SecStaticCodeCheckValidity(staticCode, [], nil)
            == errSecSuccess
    }

    private func core(at clock: TimeInterval = 100) -> KiwiCore {
        let core = makeTestCore()
        core.onLog = { _ in }
        core.inPlaceRestart.now = { clock }
        return core
    }

    @Test("an update relaunch is honoured once")
    func updateIsTakenOnce() {
        let core = core()
        core.announceUpdateRelaunch()
        #expect(core.takeInPlaceRestart())
        #expect(!core.takeInPlaceRestart())
    }

    @Test("nothing announced gathers")
    func silenceGathers() {
        #expect(!core().takeInPlaceRestart())
    }

    @Test("an intent past its bound gathers")
    func staleIntentGathers() {
        let core = core()
        var now: TimeInterval = 100
        core.inPlaceRestart.now = { now }
        core.announceUpdateRelaunch()
        now += InPlaceRestartState.bound
        #expect(core.takeInPlaceRestart())
        core.announceUpdateRelaunch()
        now += InPlaceRestartState.bound + 1
        #expect(!core.takeInPlaceRestart())
    }

    @Test(
        "service restart arms for the program this build signed",
        .enabled(if: InPlaceRestartTests.selfIsSigned)
    )
    func serviceArmsForItsOwnProgram() throws {
        let core = core()
        let path = try #require(Self.selfPath)
        core.inPlaceRestart.serviceProgram = { path }
        let response = core.execute(ServiceManager.prepareRestartCommand)
        #expect(response.isSuccess)
        #expect(
            response.data == .object(["in_place": .bool(true)])
        )
        #expect(core.takeInPlaceRestart())
    }

    @Test("service restart refuses another program and disarms")
    func serviceRefusesAnotherProgram() {
        let core = core()
        core.announceUpdateRelaunch()
        core.inPlaceRestart.serviceProgram = {
            URL(fileURLWithPath: "/System/Applications/Calculator.app")
        }
        let response = core.execute(ServiceManager.prepareRestartCommand)
        #expect(
            response.data == .object(["in_place": .bool(false)])
        )
        // The refusal drops the earlier intent too: what launchd
        // starts next is what the stop answers for.
        #expect(!core.takeInPlaceRestart())
    }

    @Test("service restart with no readable plist gathers")
    func serviceWithoutProgramGathers() {
        let core = core()
        core.inPlaceRestart.serviceProgram = { nil }
        #expect(!core.prepareServiceRestart())
        #expect(!core.takeInPlaceRestart())
    }

    /// The stop's two halves a test can reach: the session file
    /// carries the in-place memory only for an announced stop, and
    /// the log says which branch ran — the gather itself stands
    /// down without a running event loop.
    @Test("stop writes the in-place snapshot only when announced")
    func stopWritesInPlaceSnapshot() throws {
        for announced in [true, false] {
            let core = core()
            var lines: [String] = []
            core.onLog = { lines.append($0) }
            try FileManager.default.createDirectory(
                at: core.configDirectory,
                withIntermediateDirectories: true
            )
            core.state.workspaces.ensureSpace(SpaceID("1"))
            core.boot.reachedReady = true
            if announced { core.announceUpdateRelaunch() }
            core.stop()
            let url = core.configDirectory.appendingPathComponent(
                ".session_snapshot"
            )
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.contains("\"session\"") == announced)
            #expect(
                lines.contains { $0.contains("windows left in place") }
                    == announced
            )
            try? FileManager.default.removeItem(
                at: core.configDirectory
            )
        }
    }
}

/// `CodeIdentity` against real signed code (#930 ruling 3).
@Suite("Code identity gate (#930)")
struct CodeIdentityTests {
    @Test(
        "the running program satisfies its own requirement",
        .enabled(if: InPlaceRestartTests.selfIsSigned)
    )
    func selfIsAdmitted() throws {
        let path = try #require(InPlaceRestartTests.selfPath)
        #expect(CodeIdentity.running().admits(path) == .admitted)
    }

    @Test("another signed app is refused")
    func otherAppIsRefused() {
        let verdict = CodeIdentity.running().admits(
            URL(fileURLWithPath: "/System/Applications/Calculator.app")
        )
        #expect(verdict != .admitted)
    }

    @Test("a missing path is refused")
    func missingIsRefused() {
        let verdict = CodeIdentity.running().admits(
            URL(fileURLWithPath: "/nonexistent/KiwiDesk.app")
        )
        #expect(verdict != .admitted)
    }

    @Test("an executable is judged by its enclosing bundle")
    func executableResolvesToBundle() {
        let exe = URL(
            fileURLWithPath:
                "/Applications/KiwiDesk.app/Contents/MacOS/KiwiDesk"
        )
        #expect(
            CodeIdentity.bundle(containing: exe).path
                == "/Applications/KiwiDesk.app"
        )
        let bare = URL(fileURLWithPath: "/usr/local/bin/kiwidesk")
        #expect(CodeIdentity.bundle(containing: bare) == bare)
        // A tool that merely lives under some bundle is its own
        // code — the test runner itself sits inside Xcode.app.
        let tool = URL(
            fileURLWithPath: "/Applications/Xcode.app/Contents/"
                + "Developer/usr/bin/xctest"
        )
        #expect(CodeIdentity.bundle(containing: tool) == tool)
    }
}
