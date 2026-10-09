// P1 — does a behind-window blur render when its panel sits MID-STACK,
// below another app's window? (#2103 v0). Back to front:
//   A (our checkerboard window) → plate → B (TextEdit's front window).
// Then: is there a continuous blur axis (a "blur level" control)?
// Flags: --settle SECONDS (0.4) per variant before capture.
import AppKit

@main @MainActor
enum P1 {
    struct Sample {
        let eA: Double, eB: Double, rgbA: RGB, rgbB: RGB, ordered: Bool
    }

    static var args: Args!
    static var csv: CSV!
    static var plate: NSPanel!
    static var windowA: NSWindow!
    static var bNumber = 0
    static var regionA = CGRect.zero, regionB = CGRect.zero
    static var baseA = 1.0, baseB = 1.0
    static var settle = 0.4

    static func main() {
        args = Args(probe: "P1")
        bootApp()
        settle = Double(args.value("--settle") ?? "") ?? 0.4
        guard activate(bundleID: "com.apple.TextEdit").ok,
            let p = pid(of: "com.apple.TextEdit"),
            let b = frontWindow(ofPID: p)
        else {
            return verdict(
                args,
                "setup",
                false,
                "no TextEdit window to use as B"
            )
        }
        bNumber = b.number
        layOut(b.bounds)
        plate = makePlate(frame: NSScreen.main!.frame, spec: PlateSpec())
        csv = CSV(
            args.url("p1.csv"),
            header: [
                "label", "dim", "blur_alpha", "panel_alpha", "eA", "eB",
                "eA_ratio",
                "eB_ratio", "rgbA", "rgbB", "lumA", "ordered",
            ]
        )

        // Baseline: no plate.
        plate.orderOut(nil)
        windowA.order(.below, relativeTo: bNumber)
        pump(settle)
        let shots = captureRegions([regionA, regionB])
        guard captureLooksReal(shots[1]) else {
            return verdict(
                args,
                "setup",
                false,
                "B region has no detail: grant "
                    + "the host terminal Screen Recording and fill the "
                    + "TextEdit "
                    + "document with text"
            )
        }
        baseA = edgeEnergy(shots[0]!)
        baseB = edgeEnergy(shots[1]!)
        verdict(args, "baseline", nil, "eA \(fmt(baseA)), eB \(fmt(baseB))")

        // Mid-stack blur verdict, .active state.
        let hud = measure(
            "hud.active",
            PlateSpec(blur: .effect(.hudWindow, .active))
        )
        judgeMidStack("midstack-hud-active", hud)
        let follows = measure(
            "hud.followsWindowActiveState",
            PlateSpec(blur: .effect(.hudWindow, .followsWindowActiveState))
        )
        verdict(
            args,
            "state-follows",
            nil,
            "eA ratio \(fmt(follows.eA / baseA)) "
                + "(near 1 = the non-key panel renders inactive, no blur)"
        )
        if #available(macOS 26, *) {
            judgeMidStack(
                "midstack-glass-clear",
                measure(
                    "glass.clear",
                    PlateSpec(blur: .glass(regular: false, tint: nil))
                )
            )
            judgeMidStack(
                "midstack-glass-regular",
                measure(
                    "glass.regular",
                    PlateSpec(blur: .glass(regular: true, tint: nil))
                )
            )
        }

        sweeps()
        negatives()
        plate.orderOut(nil)
        windowA.orderOut(nil)
    }

    /// Places A so its right ~40% sits under B; regions avoid title bars.
    static func layOut(_ b: CGRect) {
        let screen = flipRect(NSScreen.main!.frame)
        var a = CGRect(
            x: b.minX - b.width * 0.6,
            y: b.minY + 40,
            width: b.width,
            height: max(200, b.height - 80)
        )
        let aLeft = a.minX >= screen.minX
        if !aLeft { a.origin.x = b.minX + b.width * 0.6 }
        windowA = makeTarget(
            frame: flipRect(a),
            pattern: .checkerboard,
            title: "P1 A"
        )
        let freeW = b.width * 0.6 - 40
        regionA = CGRect(
            x: aLeft ? a.minX + 20 : b.maxX + 20,
            y: a.minY + 40,
            width: freeW,
            height: a.height - 80
        )
        regionB = CGRect(
            x: aLeft ? a.maxX + 20 : b.minX + 20,
            y: b.minY + 60,
            width: b.width * 0.4 - 40,
            height: b.height - 120
        )
    }

    @discardableResult
    static func measure(
        _ label: String,
        _ spec: PlateSpec,
        front: Bool = false
    ) -> Sample {
        configure(plate, spec: spec)
        if front {
            plate.orderFrontRegardless()
        } else {
            plate.order(.below, relativeTo: bNumber)
            windowA.order(.below, relativeTo: plate.windowNumber)
        }
        pump(settle)
        let s = stack()
        let ordered =
            front
            || ((s.firstIndex(of: bNumber) ?? .max)
                < (s.firstIndex(of: plate.windowNumber) ?? .min)
                && (s.firstIndex(of: plate.windowNumber) ?? .max)
                    < (s.firstIndex(of: windowA.windowNumber) ?? .min))
        let shots = captureRegions([regionA, regionB])
        guard let ia = shots[0], let ib = shots[1] else {
            return Sample(
                eA: .nan,
                eB: .nan,
                rgbA: RGB(r: 0, g: 0, b: 0),
                rgbB: RGB(r: 0, g: 0, b: 0),
                ordered: ordered
            )
        }
        let out = Sample(
            eA: edgeEnergy(ia),
            eB: edgeEnergy(ib),
            rgbA: meanRGB(ia),
            rgbB: meanRGB(ib),
            ordered: ordered
        )
        csv.row([
            label, spec.dim, spec.blurAlpha, spec.panelAlpha, out.eA, out.eB,
            out.eA / baseA, out.eB / baseB, out.rgbA.text, out.rgbB.text,
            out.rgbA.luminance, ordered,
        ])
        return out
    }

    /// PASS: A ≤ 20% of baseline edge energy, B within ±2%, order held.
    static func judgeMidStack(_ name: String, _ s: Sample) {
        let rA = s.eA / baseA
        let rB = s.eB / baseB
        verdict(
            args,
            name,
            s.ordered && rA <= 0.20 && abs(rB - 1) <= 0.02,
            "A \(fmt(rA * 100))% of baseline (≤20), B \(fmt(rB * 100))% "
                + "(98–102), ordered \(s.ordered)"
        )
    }

    static let steps: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]

    /// Strength sweeps. "Continuous" iff ≥4 consecutive steps lower A's
    /// edge energy (by ≥3% each) with A's mean colour within 5/255 per
    /// channel of the dim-only plate at the matching dim.
    static func sweeps() {
        let dims: [CGFloat] = [0, 0.15, 0.3, 0.45, 0.6]
        var dimRef: [CGFloat: RGB] = [:]
        for d in dims {
            dimRef[d] = measure("dim.\(d)", PlateSpec(dim: d)).rgbA
        }
        let materials: [(String, NSVisualEffectView.Material)] = [
            ("hudWindow", .hudWindow), ("fullScreenUI", .fullScreenUI),
            ("underWindowBackground", .underWindowBackground),
            ("sidebar", .sidebar), ("menu", .menu), ("popover", .popover),
        ]
        for (name, m) in materials {
            judgeSweep(
                "\(name).blurAlpha",
                steps.map { a in
                    (
                        measure(
                            "\(name).blurAlpha.\(a)",
                            PlateSpec(
                                blur: .effect(m, .active),
                                dim: 0.3,
                                blurAlpha: a
                            )
                        ), dimRef[0.3]!
                    )
                }
            )
            // Panel alpha fades the dim too: colour will drift by design.
            judgeSweep(
                "\(name).panelAlpha",
                steps.map { a in
                    (
                        measure(
                            "\(name).panelAlpha.\(a)",
                            PlateSpec(
                                blur: .effect(m, .active),
                                dim: 0.3,
                                panelAlpha: a
                            )
                        ), dimRef[0.3]!
                    )
                }
            )
        }
        if #available(macOS 26, *) {
            judgeSweep(
                "glass.tintAlpha",
                dims.map { t in
                    (
                        measure(
                            "glass.regular.tint.\(t)",
                            PlateSpec(
                                blur: .glass(
                                    regular: true,
                                    tint: NSColor.black.withAlphaComponent(t)
                                )
                            )
                        ),
                        dimRef[t]!
                    )
                }
            )
            // Fading the glass shows its tint bare: expected to fail colour.
            judgeSweep(
                "glass.blurAlpha",
                steps.map { a in
                    (
                        measure(
                            "glass.regular.blurAlpha.\(a)",
                            PlateSpec(
                                blur: .glass(
                                    regular: true,
                                    tint: NSColor.black.withAlphaComponent(0.3)
                                ),
                                blurAlpha: a
                            )
                        ), dimRef[0.3]!
                    )
                }
            )
        }
    }

    static func judgeSweep(_ name: String, _ pts: [(Sample, RGB)]) {
        var run = 0
        var best = 0
        for i in 1..<pts.count {
            run = pts[i].0.eA <= pts[i - 1].0.eA * 0.97 ? run + 1 : 0
            best = max(best, run)
        }
        let drift = pts.map { $0.0.rgbA.maxChannelDelta($0.1) }.max() ?? .nan
        verdict(
            args,
            "axis-\(name)",
            best >= 4 && drift <= 5,
            "monotonic steps \(best) (≥4), max colour drift "
                + "\(fmt(drift))/255 "
                + "(≤5); eA ratios "
                + pts.map { fmt($0.0.eA / baseA) }.joined(separator: " ")
        )
    }

    /// NEG: an opaque magenta plate must read magenta at A and leave B;
    /// the same blur ordered at the very front must blur B.
    static func negatives() {
        let mag = measure("neg.magenta", PlateSpec(blur: .solid(.magenta)))
        let isMagenta =
            mag.rgbA.maxChannelDelta(RGB(r: 255, g: 0, b: 255)) <= 40
        verdict(
            args,
            "neg-magenta",
            isMagenta && abs(mag.eB / baseB - 1) <= 0.02,
            "A mean \(mag.rgbA.text) (≈255,0,255), B "
                + "\(fmt(mag.eB / baseB * 100))%"
        )
        let front = measure(
            "neg.hud.front",
            PlateSpec(blur: .effect(.hudWindow, .active)),
            front: true
        )
        verdict(
            args,
            "neg-front-blurs-B",
            front.eB / baseB <= 0.5,
            "B at \(fmt(front.eB / baseB * 100))% of baseline "
                + "(≤50 proves the "
                + "metric sees a blur over B)"
        )
    }
}
