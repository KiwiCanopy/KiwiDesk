// P6 — can several apps' windows be raised ABOVE the plate without
// activating each app? (#2103 v0, feeds v3's named app sets.)
// Run from Terminal (the HOST: frontmost at start, must keep the key
// window). TextEdit and Preview each need one open window. The host
// terminal needs Accessibility. Flags: --runs N (20).
import AppKit
import ApplicationServices

@main @MainActor
enum P6 {
    static let raised = ["com.apple.TextEdit", "com.apple.Preview"]
    static var activations: [String] = []

    static func main() {
        let args = Args(probe: "P6")
        bootApp()
        guard AXIsProcessTrusted() else {
            return verdict(
                args,
                "setup",
                false,
                "not AX-trusted: grant the host "
                    + "terminal Accessibility "
                    + "(System Settings ▸ Privacy & Security)"
            )
        }
        guard let host = NSWorkspace.shared.frontmostApplication,
            let hostWin = frontWindow(ofPID: host.processIdentifier),
            let hostBundle = host.bundleIdentifier
        else {
            return verdict(args, "setup", false, "no frontmost host window")
        }
        let pids = raised.compactMap { pid(of: $0) }
        guard pids.count == raised.count else {
            return verdict(
                args,
                "setup",
                false,
                "open TextEdit and Preview first"
            )
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app =
                note.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            let id = app?.bundleIdentifier ?? "?"
            MainActor.assumeIsolated { activations.append(id) }
        }
        let plate = makePlate(
            frame: NSScreen.main!.frame,
            spec: PlateSpec(dim: 0.4)
        )
        let csv = CSV(
            args.url("p6.csv"),
            header: [
                "run", "buried_at_start", "ax_ms", "ax_errors",
                "both_above_plate",
                "activations", "front_after", "host_key",
            ]
        )
        let runs = args.int("--runs", 20)
        var pass = 0
        var buriedOK = 0
        for run in 0..<runs {
            let buried = bury(
                hostPID: host.processIdentifier,
                hostWin: hostWin.number,
                plate: plate,
                pids: pids
            )
            if buried { buriedOK += 1 }
            activations = []
            var errors = 0
            let t = timed {
                for p in pids { if !raiseFront(of: p) { errors += 1 } }
            }
            pump(0.5)
            let above = pids.allSatisfy { aboveIndex($0, plate) }
            let front =
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                ?? "?"
            let hostKey = focusedAppPID() == host.processIdentifier
            let ok =
                buried && above && activations.isEmpty && front == hostBundle
                && hostKey
            if ok { pass += 1 }
            csv.row([
                run, buried, t, errors, above,
                activations.joined(separator: ";"),
                front, hostKey,
            ])
        }
        verdict(
            args,
            "raise-without-activation",
            pass == runs,
            "\(pass)/\(runs) runs: both windows above the plate, "
                + "no activation, "
                + "\(hostBundle) kept key (bar \(runs)/\(runs))"
        )
        verdict(
            args,
            "neg-buried-at-start",
            buriedOK == runs,
            "\(buriedOK)/\(runs) runs started with both windows "
                + "below the plate"
        )

        // NEG: a real activation must be caught by the watcher.
        _ = bury(
            hostPID: host.processIdentifier,
            hostWin: hostWin.number,
            plate: plate,
            pids: pids
        )
        activations = []
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: raised[0]
        ) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: cfg,
                completionHandler: nil
            )
        }
        pump(1.0)
        verdict(
            args,
            "neg-activate-caught",
            activations.contains(raised[0]),
            "watcher saw [\(activations.joined(separator: ", "))]"
        )
        // Hand the desk back to the host.
        _ = activate(bundleID: hostBundle)
        plate.orderOut(nil)
    }

    /// Host window front (AX raise: the host is the active app), plate
    /// directly below it, so every other window is under the plate.
    /// Returns whether both raised apps' windows read back below it.
    static func bury(
        hostPID: pid_t,
        hostWin: Int,
        plate: NSPanel,
        pids: [pid_t]
    ) -> Bool {
        _ = raiseFront(of: hostPID)
        pump(0.2)
        plate.order(.below, relativeTo: hostWin)
        pump(0.2)
        return pids.allSatisfy { !aboveIndex($0, plate) }
    }

    /// Whether the app's front document window sits above the plate.
    static func aboveIndex(_ pid: pid_t, _ plate: NSPanel) -> Bool {
        let s = stack()
        guard let w = frontWindow(ofPID: pid),
            let iw = s.firstIndex(of: w.number),
            let ip = s.firstIndex(of: plate.windowNumber)
        else { return false }
        return iw < ip
    }

    /// AXRaise on the app's first AX window (its frontmost).
    static func raiseFront(of pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                app,
                kAXWindowsAttribute as CFString,
                &value
            )
                == .success,
            let windows = value as? [AXUIElement], let first = windows.first
        else { return false }
        return AXUIElementPerformAction(first, kAXRaiseAction as CFString)
            == .success
    }

    /// The system-wide focused application's pid (who holds the key window).
    static func focusedAppPID() -> pid_t? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                AXUIElementCreateSystemWide(),
                kAXFocusedApplicationAttribute as CFString,
                &value
            ) == .success, let v = value,
            CFGetTypeID(v) == AXUIElementGetTypeID()
        else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(v as! AXUIElement, &pid)
        return pid
    }
}
