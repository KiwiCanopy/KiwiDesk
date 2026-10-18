import AppKit
import KiwiDeskCore

// CLI dispatch when arguments are supplied.
if CommandLine.arguments.count > 1 {
    exit(runCLI(CommandLine.arguments))
}

// Holds `.accessory` for its whole life — content windows come
// forward through `NSApp.forceFront`, never a policy flip
// ("Permanent accessory mode", docs/design-decisions.md).
// The first `shared` read picks the class (#2049).
let app = KiwiApplication.shared

// Single-instance lock held for process lifetime (#196). Must
// run before the delegate exists: a second KiwiCore would
// clobber the running instance's IPC socket.
let instanceLock = SingleInstanceLock(path: MachineLocation.lockPath)
if !instanceLock.acquire() {
    surfaceRunningInstanceAndExit()
}
// A pre-#2324 build still running holds the lock's old home.
let legacyLock = MachineLocation.legacyLockPath
if SingleInstanceLock.legacyHolderRuns(at: legacyLock) {
    surfaceRunningInstanceAndExit()
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
