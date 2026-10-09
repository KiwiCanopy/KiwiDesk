// P4 helper — holds one plate per screen directly below the focused
// window, re-ordering on every app activation and on a front-window
// change inside the app (polled). Runs until Ctrl-C, which orders the
// plates out. The procedure that uses it is P4_PlateCost.md.
// NOTE: it orders below the focused window, so it can land between that
// window and KiwiDesk's focus ring (also ordered below it): the cost is
// the point here, not the look.
// Flags: --kind dim|hud|glass (hud), --dim 0.3, --poll SECONDS (0.25).
import AppKit

@main @MainActor
enum P4 {
    static var plates: [NSPanel] = []
    static var csv: CSV!
    static var lastTarget = -1
    static var reorders = 0
    static var times: [Double] = []

    static func main() {
        let args = Args(probe: "P4")
        bootApp()
        let dim = CGFloat(Double(args.value("--dim") ?? "") ?? 0.3)
        let blur: Blur
        switch args.value("--kind") ?? "hud" {
        case "dim": blur = .none
        case "glass":
            if #available(macOS 26, *) {
                blur = .glass(regular: true, tint: nil)
            } else {
                blur = .effect(.hudWindow, .active)
            }
        default: blur = .effect(.hudWindow, .active)
        }
        let spec = PlateSpec(blur: blur, dim: dim)
        plates = NSScreen.screens.map {
            makePlate(frame: $0.frame, spec: spec)
        }
        csv = CSV(
            args.url("p4-holder.csv"),
            header: ["t_s", "cause", "target", "order_ms"]
        )
        let started = nowNS()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { reorder("activation", since: started) }
        }
        let poll = Double(args.value("--poll") ?? "") ?? 0.25
        _ = Timer.scheduledTimer(withTimeInterval: poll, repeats: true) { _ in
            MainActor.assumeIsolated { reorder("poll", since: started) }
        }
        let stop = DispatchSource.makeSignalSource(
            signal: SIGINT,
            queue: .main
        )
        signal(SIGINT, SIG_IGN)
        stop.setEventHandler {
            MainActor.assumeIsolated {
                plates.forEach { $0.orderOut(nil) }
                verdict(
                    args,
                    "holder",
                    nil,
                    "\(reorders) re-orders; order call p50 "
                        + "\(fmt(percentile(times, 50))) ms, p99 "
                        + "\(fmt(percentile(times, 99))) "
                        + "ms, max \(fmt(times.max() ?? .nan)) ms"
                )
            }
            exit(0)
        }
        stop.resume()
        reorder("start", since: started)
        let kind = args.value("--kind") ?? "hud"
        print(
            "[P4] holding \(plates.count) plate(s), kind \(kind), "
                + "dim \(dim). Ctrl-C to stop."
        )
        RunLoop.main.run()
    }

    /// Orders every plate below the frontmost app's front window. A
    /// plate on another screen sits below it too: one stack per Desktop.
    static func reorder(_ cause: String, since start: UInt64) {
        guard let front = NSWorkspace.shared.frontmostApplication,
            front.processIdentifier
                != ProcessInfo.processInfo.processIdentifier,
            let target = frontWindow(ofPID: front.processIdentifier)
        else { return }
        if cause == "poll" && target.number == lastTarget { return }
        lastTarget = target.number
        let t = timed {
            for p in plates { p.order(.below, relativeTo: target.number) }
        }
        reorders += 1
        times.append(t)
        csv.row([ms(since: start) / 1000, cause, target.number, t])
    }
}
