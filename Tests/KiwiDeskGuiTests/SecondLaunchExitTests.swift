import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A second launch that finds the lock held must report
/// SUCCESS, because launchd reads that status to decide whether
/// to respawn (#1068).
///
/// The invariant is a PAIR, and neither half means anything
/// alone: the service plist says
/// `KeepAlive { SuccessfulExit: false }` — restart only what
/// exited unsuccessfully — and the second-launch path exits
/// zero. Break either and `RunAtLoad` beside a running instance
/// becomes an infinite respawn: launch, find the lock held,
/// activate the running app (stealing the user's focus), exit,
/// be called a crash, respawn one throttle later.
///
/// So the two are asserted together, in one suite, rather than
/// each looking correct beside the other. The device capture is
/// on the issue: focus taken every ~10 s for as long as the
/// login item was enabled.
@Suite("Second-launch exit status (#1068)")
struct SecondLaunchExitTests {
    @Test("A second launch reports success, so launchd rests")
    func secondLaunchIsNotAFailure() {
        #expect(secondLaunchExitStatus == 0)
    }

    @Test("The plist restarts only an unsuccessful exit")
    func plistRestartsOnlyFailures() throws {
        // Read the shipped plist rather than restating it: the
        // exit status above is only safe BECAUSE of this key,
        // and a plist that dropped the condition would make
        // every clean quit respawn (#341's own defect, one
        // direction over).
        let plist = ServiceManager.plistContent(
            executable: "/tmp/KiwiDesk"
        )
        #expect(plist.contains("KeepAlive"))
        #expect(plist.contains("SuccessfulExit"))
        // The value under SuccessfulExit is false — the whole
        // clause is what makes a clean exit final.
        let key = try #require(
            plist.range(of: "SuccessfulExit")
        )
        let after = plist[key.upperBound...].prefix(80)
        #expect(after.contains("<false/>"))
    }
}
