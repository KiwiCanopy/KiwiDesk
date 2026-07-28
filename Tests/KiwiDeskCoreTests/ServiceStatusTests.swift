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

    @Test("Restart of a loaded job reads as a real restart")
    func restartLoadedMessage() {
        #expect(
            ServiceManager.restartMessage(wasLoaded: true)
                == "KiwiDesk service restarted"
        )
    }

    @Test("Restart of a stopped job reads as a plain start")
    func restartNotLoadedMessage() {
        #expect(
            ServiceManager.restartMessage(wasLoaded: false)
                == "KiwiDesk service was not running — started it"
        )
    }

    // MARK: - Structured status (#576)

    @Test("A running job maps to loaded with its pid")
    func structuredRunning() {
        let output =
            "org.kiwidesk.KiwiDesk = {\n"
            + "\tstate = running\n\tpid = 4271\n}"
        let status = ServiceManager.serviceStatus(
            printExit: 0,
            output: output
        )
        #expect(status == ServiceStatus(isLoaded: true, pid: 4271))
        #expect(status.isRunning)
    }

    @Test("A loaded-but-idle job maps to loaded with no pid")
    func structuredIdle() {
        let status = ServiceManager.serviceStatus(
            printExit: 0,
            output: "\tstate = not running\n"
        )
        #expect(status == ServiceStatus(isLoaded: true, pid: nil))
        // Loaded (RunAtLoad, so it auto-starts) but not running.
        #expect(!status.isRunning)
    }

    @Test("A non-zero print exit maps to not loaded")
    func structuredNotLoaded() {
        // `launchctl print` on an unloaded job exits non-zero; the
        // output (its error noise) is irrelevant to the mapping.
        let status = ServiceManager.serviceStatus(
            printExit: 113,
            output: "Could not find service"
        )
        #expect(status == ServiceStatus(isLoaded: false, pid: nil))
        #expect(!status.isRunning)
    }
}
