import Foundation

/// Where an in-place restart was announced from (#930 ruling 1).
public enum InPlaceRestartSource: String, Sendable {
    /// Sparkle's relaunch hand-off, after its own validation of
    /// the update — no identity gate of ours.
    case update
    /// `kiwidesk service restart`, gated on `CodeIdentity`.
    case service
}

/// The one home of the in-place restart intent (#930): SENT,
/// never inferred — a stop and a restart reach the app as the
/// same SIGTERM, so only an announcement tells them apart. Held
/// in memory only, consumed by the next `stop()` alone, and
/// honoured only within `bound` of its announcement, so an intent
/// whose stop never came can never make a later Quit skip the
/// gather. A new path that relaunches KiwiDesk announces through
/// `announceUpdateRelaunch` or `prepare_restart`, or it gathers.
struct InPlaceRestartState {
    /// Long enough for Sparkle's quit (its watch waits 10 s),
    /// far shorter than any later, unrelated Quit.
    static let bound: TimeInterval = 30

    var announcedAt: TimeInterval?
    /// The clock the bound is measured on (tests.md, #1456).
    var now: () -> TimeInterval = {
        ProcessInfo.processInfo.systemUptime
    }
    /// This process's identity, read at launch (the first core),
    /// while the bundle on disk is the one that launched.
    static let launchIdentity = CodeIdentity.running()
    var identity = InPlaceRestartState.launchIdentity
    /// The program launchd will start for the service.
    var serviceProgram: () -> URL? = ServiceManager.programURL
}

extension KiwiCore {
    /// Sparkle is about to relaunch into the update it validated
    /// (#930 ruling 1, the update window's Install and
    /// Relaunch). An automatic install never relaunches, so it
    /// never reaches here and still gathers.
    public func announceUpdateRelaunch() {
        arm(.update)
    }

    /// `prepare_restart`: the CLI is about to replace a loaded
    /// service. Armed only when the program launchd will start
    /// satisfies this process's own requirement (ruling 3);
    /// otherwise any earlier intent is dropped and the stop
    /// gathers. Returns whether it armed.
    func prepareServiceRestart() -> Bool {
        guard let program = inPlaceRestart.serviceProgram() else {
            disarm("no service program to check")
            return false
        }
        switch inPlaceRestart.identity.admits(program) {
        case .admitted:
            arm(.service)
            return true
        case .refused(let why):
            disarm("\(program.path) refused (\(why))")
            return false
        }
    }

    /// Consumes the intent: true only for one announced within
    /// the bound. `stop()`'s one question.
    func takeInPlaceRestart() -> Bool {
        defer { inPlaceRestart.announcedAt = nil }
        guard let at = inPlaceRestart.announcedAt else {
            return false
        }
        let age = inPlaceRestart.now() - at
        guard age <= InPlaceRestartState.bound else {
            onLog(
                "in-place restart: announced \(Int(age))s ago; "
                    + "gathering"
            )
            return false
        }
        return true
    }

    private func arm(_ source: InPlaceRestartSource) {
        inPlaceRestart.announcedAt = inPlaceRestart.now()
        onLog("in-place restart announced (\(source.rawValue))")
    }

    private func disarm(_ reason: String) {
        inPlaceRestart.announcedAt = nil
        onLog("in-place restart refused: \(reason); will gather")
    }
}
