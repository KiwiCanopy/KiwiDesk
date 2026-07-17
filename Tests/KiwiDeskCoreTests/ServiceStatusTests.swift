import Testing

@testable import KiwiDeskCore

/// Pure helpers behind the `service status` verb (#328). The
/// launchctl-driven paths (start/stop/restart/isLoaded) mutate
/// real launchd state and aren't exercised here.
@Suite("Service status parsing")
struct ServiceStatusTests {
    @Test("Extracts the pid from tab-indented launchctl output")
    func parsesPID() {
        // Real `launchctl print` indents with tabs, not spaces.
        let output =
            "org.kiwidesk.KiwiDesk = {\n"
            + "\tactive count = 1\n"
            + "\tstate = running\n"
            + "\tpid = 4271\n"
            + "\tprogram = /usr/local/bin/KiwiDesk\n"
            + "}"
        #expect(ServiceManager.parsePID(from: output) == 4271)
    }

    @Test("Ignores a pid substring that isn't its own line")
    func ignoresPIDSubstring() {
        let output = "\tspawn type = pid = should-not-match\n"
        #expect(ServiceManager.parsePID(from: output) == nil)
    }

    @Test("Skips a malformed pid line and keeps scanning")
    func skipsMalformedPIDLine() {
        let output = "\tpid = \n\tpid = 88\n"
        #expect(ServiceManager.parsePID(from: output) == 88)
    }

    @Test("Returns nil when no pid line is present")
    func noPIDWhenIdle() {
        let output = """
            org.kiwidesk.KiwiDesk = {
                state = not running
            }
            """
        #expect(ServiceManager.parsePID(from: output) == nil)
    }

    @Test("Running message names the pid")
    func runningMessage() {
        #expect(
            ServiceManager.statusMessage(pid: 42)
                == "KiwiDesk service is running (pid 42)"
        )
    }

    @Test("Loaded-but-idle message flags no process")
    func idleMessage() {
        #expect(
            ServiceManager.statusMessage(pid: nil)
                == "KiwiDesk service is loaded but not running"
        )
    }
}
