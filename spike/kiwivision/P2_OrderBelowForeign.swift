// P2 — does ordering `.below` a FOREIGN window read back reliably,
// with the plate below the ring stand-in? (#2103 v0, borders.md,
// #1962). Same call shape as AppKitBorderOverlay.order(relativeTo:):
//   ring.order(.below, relativeTo: target)
//   plate.order(.below, relativeTo: ring)
// Flags: --iterations N (200), --skylight-neg N (20).
import AppKit

/// UNVERIFIED: SLSOrderWindow(cid, wid, mode, relativeTo) with mode
/// 1 = above, -1 = below, 0 = out — the CGS-era shape, never probed
/// on macOS 27. Resolved by dlsym; nil skips the SkyLight negative.
typealias SLSOrderWindowFn =
    @convention(c) (Int32, UInt32, Int32, UInt32) -> Int32
typealias SLSMainConnectionFn = @convention(c) () -> Int32

@main @MainActor
enum P2 {
    static let apps = [
        "com.apple.TextEdit", "com.apple.Preview", "com.apple.Terminal",
    ]

    static func main() {
        let args = Args(probe: "P2")
        bootApp()
        let n = args.int("--iterations", 200)
        let screen = NSScreen.main!.frame
        let plate = makePlate(frame: screen, spec: PlateSpec(dim: 0.15))
        let ring = makeRingStandIn()
        let csv = CSV(
            args.url("p2.csv"),
            header: [
                "i", "app", "via", "target", "pre_plate_in_front", "ring_ms",
                "plate_ms", "readback", "latency_ms", "rel_order_ok",
            ]
        )
        var attempts = 0
        var ok = 0
        var missed = 0
        var negPrecheckFail = 0
        var orderMS: [Double] = []
        var latencies: [Double] = []
        var lastTarget: (num: Int, pid: pid_t)?

        for i in 0..<n {
            let bid = apps[i % apps.count]
            let act = activate(bundleID: bid)
            guard act.ok, let p = pid(of: bid),
                let target = frontWindow(ofPID: p)
            else {
                missed += 1
                csv.row([i, bid, act.via, -1, "", "", "", "skip", "", ""])
                continue
            }
            attempts += 1
            lastTarget = (target.number, p)
            // NEGATIVE CONTROL: start in FRONT, so "already there" can't pass.
            plate.orderFrontRegardless()
            ring.orderFrontRegardless()
            pump(0.02)
            let pre = stack()
            let preFront =
                (pre.firstIndex(of: plate.windowNumber) ?? .max)
                < (pre.firstIndex(of: target.number) ?? .max)
            if !preFront { negPrecheckFail += 1 }
            ring.setFrame(
                flipRect(target.bounds.insetBy(dx: -4, dy: -4)),
                display: false
            )
            let tRing = timed { ring.order(.below, relativeTo: target.number) }
            let tPlate = timed {
                plate.order(.below, relativeTo: ring.windowNumber)
            }
            orderMS += [tRing, tPlate]
            let (lat, relOK) = pollAdjacency(
                target.number,
                ring.windowNumber,
                plate.windowNumber
            )
            if let lat, lat <= 100 { ok += 1 }
            if let lat { latencies.append(lat) }
            csv.row([
                i, bid, act.via, target.number, preFront, tRing, tPlate,
                lat != nil ? "ok" : "miss", lat ?? -1, relOK,
            ])
        }

        let p99 = percentile(orderMS, 99)
        verdict(
            args,
            "readback",
            attempts == n && ok == n,
            "\(ok)/\(attempts) read back target,ring,plate at +0/+1/+2 "
                + "within 100 ms (\(missed) activation misses; bar \(n)/\(n))"
        )
        verdict(
            args,
            "order-call-p99",
            p99 < 5,
            "p99 \(fmt(p99)) ms, max \(fmt(orderMS.max() ?? .nan)) ms "
                + "(bar < 5 ms idle)"
        )
        verdict(
            args,
            "readback-latency",
            nil,
            "p50 \(fmt(percentile(latencies, 50))) ms, "
                + "p99 \(fmt(percentile(latencies, 99))) ms"
        )
        verdict(
            args,
            "neg-start-in-front",
            negPrecheckFail == 0,
            "\(attempts - negPrecheckFail)/\(attempts) iterations started "
                + "with the plate in front of the target"
        )

        if let lastTarget {
            skyLightNegative(args, target: lastTarget, plate: plate)
        }
        plate.orderOut(nil)
        ring.orderOut(nil)
    }

    /// Polls stack() every 10 ms for up to 500 ms. Returns the latency
    /// at which target, ring, plate sat at consecutive indices, and
    /// whether at least their relative order was right at the end.
    static func pollAdjacency(_ t: Int, _ r: Int, _ p: Int) -> (Double?, Bool)
    {
        let start = nowNS()
        var relOK = false
        while ms(since: start) < 500 {
            let s = stack()
            if let it = s.firstIndex(of: t), let ir = s.firstIndex(of: r),
                let ip = s.firstIndex(of: p)
            {
                relOK = it < ir && ir < ip
                if ir == it + 1 && ip == it + 2 {
                    return (ms(since: start), true)
                }
            }
            pump(0.01)
        }
        return (nil, relOK)
    }

    /// Per #1962, WindowServer applies no SkyLight order to an AppKit
    /// panel: this is EXPECTED to fail read-back. A pass here is news.
    static func skyLightNegative(
        _ args: Args,
        target: (num: Int, pid: pid_t),
        plate: NSPanel
    ) {
        let count = args.int("--skylight-neg", 20)
        guard
            let order = skyLightSymbol(
                "SLSOrderWindow",
                as: SLSOrderWindowFn.self
            ),
            let cidFn = skyLightSymbol(
                "SLSMainConnectionID",
                as: SLSMainConnectionFn.self
            )
        else {
            verdict(
                args,
                "neg-skylight-order",
                nil,
                "SLSOrderWindow or SLSMainConnectionID absent — skipped"
            )
            return
        }
        let cid = cidFn()
        var applied = 0
        var errors: [Int32] = []
        for _ in 0..<count {
            plate.orderFrontRegardless()
            pump(0.05)
            let err = order(
                cid,
                UInt32(plate.windowNumber),
                -1,
                UInt32(target.num)
            )
            if err != 0 { errors.append(err) }
            let start = nowNS()
            while ms(since: start) < 500 {
                let s = stack()
                if let it = s.firstIndex(of: target.num),
                    let ip = s.firstIndex(of: plate.windowNumber), ip > it
                {
                    applied += 1
                    break
                }
                pump(0.01)
            }
        }
        verdict(
            args,
            "neg-skylight-order",
            applied == 0,
            "SkyLight order applied \(applied)/\(count) (expected 0 per "
                + "#1962); nonzero CGError returns: \(errors.count)"
        )
    }
}
