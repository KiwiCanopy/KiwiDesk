// P7 — what does one extra panel order per FLOAT cost on each focus
// change? (#2103 ruling 3, #1925). P2's loop (ring below the focused
// foreign window, plate below the ring) plus k dim panels, each ordered
// `.above` its own float stand-in. The floats belong to a CHILD process
// (this binary re-run with --float-host k), so every order is relative
// to a foreign window, as in v1. Run idle AND under the measure-work GPU
// page (README). Flags: --iterations N per k (100), --ks 0,1,3,6.
import AppKit

@main @MainActor
enum P7 {
    static let apps = [
        "com.apple.TextEdit", "com.apple.Preview", "com.apple.Terminal",
    ]

    static func main() {
        if let k = CommandLine.arguments.firstIndex(of: "--float-host") {
            return floatHost(Int(CommandLine.arguments[k + 1]) ?? 0)
        }
        let args = Args(probe: "P7")
        bootApp()
        let n = args.int("--iterations", 100)
        let ks = (args.value("--ks") ?? "0,1,3,6").split(separator: ",")
            .compactMap {
                Int($0)
            }
        let gpuStart = gpuBusy()
        verdict(
            args,
            "gpu-at-start",
            nil,
            "Device Utilization \(gpuStart ?? -1)% "
                + "(GPU condition needs ≥90)"
        )
        let (child, floats) = spawnFloats(ks.max() ?? 0)
        defer { child?.terminate() }
        let plate = makePlate(
            frame: NSScreen.main!.frame,
            spec: PlateSpec(dim: 0.15)
        )
        let ring = makeRingStandIn()
        let csv = CSV(
            args.url("p7.csv"),
            header: [
                "k", "i", "app", "ring_ms", "plate_ms", "floats_ms",
                "max_call_ms",
                "reorder_held_ms", "neg_started_below", "moved_above",
            ]
        )
        var addedByK: [Int: [Double]] = [:]
        var maxCall = 0.0
        var stalls = 0
        var negOK = 0
        var negTotal = 0

        for k in ks where k <= floats.count {
            let mine = floats.prefix(k)
            let panels = mine.map { f -> NSPanel in
                let p = makePlate(
                    frame: flipRect(f.bounds),
                    spec: PlateSpec(dim: 0.4)
                )
                p.level = .floating
                return p
            }
            for i in 0..<n {
                let bid = apps[i % apps.count]
                guard activate(bundleID: bid).ok, let pidv = pid(of: bid),
                    let target = frontWindow(ofPID: pidv)
                else { continue }
                // NEGATIVE CONTROL: each float panel starts BELOW its float.
                for (p, f) in zip(panels, mine) {
                    p.order(.below, relativeTo: f.number)
                }
                pump(0.02)
                let pre = stack()
                let startedBelow = zip(panels, mine).allSatisfy { pair in
                    (pre.firstIndex(of: pair.0.windowNumber) ?? .min)
                        > (pre.firstIndex(of: pair.1.number) ?? .max)
                }
                let tRing = timed {
                    ring.order(.below, relativeTo: target.number)
                }
                let tPlate = timed {
                    plate.order(.below, relativeTo: ring.windowNumber)
                }
                var calls = [tRing, tPlate]
                var floatsMS = 0.0
                for (p, f) in zip(panels, mine) {
                    let t = timed { p.order(.above, relativeTo: f.number) }
                    calls.append(t)
                    floatsMS += t
                }
                // An order to the position each panel already holds.
                var heldMS = 0.0
                for (p, f) in zip(panels, mine) {
                    heldMS += timed { p.order(.above, relativeTo: f.number) }
                }
                pump(0.05)
                let post = stack()
                let moved = zip(panels, mine).allSatisfy { pair in
                    guard let ip = post.firstIndex(of: pair.0.windowNumber),
                        let iF = post.firstIndex(of: pair.1.number)
                    else { return false }
                    return ip == iF - 1
                }
                if k > 0 {
                    negTotal += 1
                    if startedBelow && moved { negOK += 1 }
                }
                let worst = calls.max() ?? 0
                maxCall = max(maxCall, worst)
                if worst >= 300 { stalls += 1 }
                addedByK[k, default: []].append(floatsMS)
                csv.row([
                    k, i, bid, tRing, tPlate, floatsMS, worst, heldMS,
                    startedBelow, moved,
                ])
            }
            panels.forEach { $0.orderOut(nil) }
            let added = addedByK[k] ?? []
            verdict(
                args,
                "k=\(k)",
                nil,
                "added p50 \(fmt(percentile(added, 50))) ms, "
                    + "p99 \(fmt(percentile(added, 99))) ms, "
                    + "max \(fmt(added.max() ?? .nan)) ms"
            )
        }
        let k3 = percentile(addedByK[3] ?? [], 99)
        verdict(
            args,
            "v1-floats",
            k3 <= 16 && maxCall <= 100,
            "k=3 added p99 \(fmt(k3)) ms (≤16), worst single call "
                + "\(fmt(maxCall)) ms (≤100)"
        )
        verdict(
            args,
            "stall-#1925",
            stalls == 0,
            "\(stalls) focus changes with a call ≥300 ms — "
                + "any one moves floats to v2"
        )
        verdict(
            args,
            "neg-moved-above",
            negOK == negTotal,
            "\(negOK)/\(negTotal) started below their float and "
                + "read back directly above"
        )
        verdict(
            args,
            "gpu-at-end",
            nil,
            "Device Utilization \(gpuBusy() ?? -1)%"
        )
        plate.orderOut(nil)
        ring.orderOut(nil)
    }

    /// Re-runs this binary as a separate process holding `k` floating
    /// windows; returns it and their WindowServer infos.
    static func spawnFloats(_ k: Int) -> (Process?, [WinInfo]) {
        guard k > 0 else { return (nil, []) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        p.arguments = [NSTemporaryDirectory(), "--float-host", "\(k)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        guard (try? p.run()) != nil else { return (nil, []) }
        var text = ""
        while text.components(separatedBy: "WIN ").count - 1 < k {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            text += String(decoding: data, as: UTF8.self)
        }
        let numbers = text.components(separatedBy: "\n").compactMap { line in
            line.hasPrefix("WIN ") ? Int(line.dropFirst(4)) : nil
        }
        pump(0.2)
        let all = windowList()
        return (p, numbers.compactMap { n in all.first { $0.number == n } })
    }

    /// Child mode: k small `.floating` windows (the float tier is raised
    /// above tiled windows, #1286), spread across the main screen.
    static func floatHost(_ k: Int) {
        bootApp()
        let v = NSScreen.main!.visibleFrame
        var windows: [NSWindow] = []
        for i in 0..<k {
            let frame = CGRect(
                x: v.minX + 60 + CGFloat(i % 3) * 300,
                y: v.minY + 80 + CGFloat(i / 3) * 220,
                width: 260,
                height: 180
            )
            let w = makeTarget(
                frame: frame,
                pattern: .gradient,
                title: "float \(i)"
            )
            w.level = .floating
            w.orderFrontRegardless()
            windows.append(w)
        }
        pump(0.2)
        for w in windows { print("WIN \(w.windowNumber)") }
        fflush(stdout)
        RunLoop.main.run()
    }
}
