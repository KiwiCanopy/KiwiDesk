// P3 — what does a full-screen plate look like as a HAZE: uniform blur,
// or Liquid Glass refraction bending the edges? (#2103 v0). Our own
// windows only: a full-visible-frame target (1-pt line grid over a
// gradient) plus a checkerboard window whose left edge a crop crosses.
// Writes PNGs and a static, script-free contact sheet (index.html).
// Hide the Dock (or it sits over the bottom crops). Flags: --settle (0.5).
import AppKit

@main @MainActor
enum P3 {
    struct Crop {
        let name: String
        let rect: CGRect
        let isEdge: Bool
    }
    struct Row {
        let label: String
        let energy: [Double]
        let ratio: [Double]
        let disp: [Double?]
    }

    static var args: Args!

    static func main() {
        args = Args(probe: "P3")
        bootApp()
        let settle = Double(args.value("--settle") ?? "") ?? 0.5
        let screenAK = NSScreen.main!.frame
        let visible = flipRect(NSScreen.main!.visibleFrame)  // CG
        let scale = NSScreen.main!.backingScaleFactor
        let lines = makeTarget(
            frame: NSScreen.main!.visibleFrame,
            pattern: .lineGrid,
            title: "P3 grid"
        )
        let boxCG = CGRect(
            x: visible.minX + visible.width * 0.65,
            y: visible.midY - 150,
            width: visible.width * 0.25,
            height: 300
        )
        let box = makeTarget(
            frame: flipRect(boxCG),
            pattern: .checkerboard,
            title: "P3 box"
        )
        let crops = layoutCrops(
            visible,
            side: 400 / scale,
            windowEdgeX: boxCG.minX
        )
        let plate = makePlate(frame: screenAK, spec: PlateSpec())
        let dir = args.out.appendingPathComponent("p3", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let csv = CSV(
            args.url("p3.csv"),
            header: [
                "label", "crop", "edge_energy",
                "ratio_to_none", "displacement_px",
            ]
        )

        // NEGATIVE CONTROL / baseline: no plate.
        plate.orderOut(nil)
        box.orderFrontRegardless()
        pump(settle)
        let base = shoot("none", crops, visible, dir)
        let baseProfiles = base.map { img in img.map { lineProfile($0) } }
        var rows = [
            Row(
                label: "none",
                energy: base.map { $0.map(edgeEnergy) ?? .nan },
                ratio: base.map { _ in 1 },
                disp: base.map { _ in 0 }
            )
        ]

        var kinds: [(String, Blur)] = [
            ("hud", .effect(.hudWindow, .active)),
            ("fullScreenUI", .effect(.fullScreenUI, .active)),
        ]
        if #available(macOS 26, *) {
            kinds += [
                ("glassClear", .glass(regular: false, tint: nil)),
                ("glassRegular", .glass(regular: true, tint: nil)),
                (
                    "glassRegularBlack0.3",
                    .glass(
                        regular: true,
                        tint: NSColor.black.withAlphaComponent(0.3)
                    )
                ),
            ]
        }
        for (kind, blur) in kinds {
            for dim in [CGFloat(0), 0.3, 0.6] {
                let label = "\(kind)_dim\(dim)"
                configure(plate, spec: PlateSpec(blur: blur, dim: dim))
                plate.order(.above, relativeTo: box.windowNumber)
                pump(settle)
                let shots = shoot(label, crops, visible, dir)
                let e = shots.map { $0.map(edgeEnergy) ?? .nan }
                let ratio = zip(e, rows[0].energy).map { $0 / $1 }
                let disp = shots.indices.map { i -> Double? in
                    guard let img = shots[i], let b = baseProfiles[i] else {
                        return nil
                    }
                    return displacement(base: b, now: lineProfile(img))
                }
                rows.append(
                    Row(label: label, energy: e, ratio: ratio, disp: disp)
                )
                for i in crops.indices {
                    csv.row([
                        label, crops[i].name, e[i], ratio[i], disp[i] ?? -1,
                    ])
                }
                judge(label, crops, ratio, disp)
            }
        }
        plate.orderOut(nil)
        lines.orderOut(nil)
        box.orderOut(nil)
        writeSheet(rows, crops, dir)
        verdict(
            args,
            "contact-sheet",
            nil,
            dir.appendingPathComponent("index.html").path
        )
    }

    /// Four corners and four edge midpoints of the visible frame, the
    /// centre, and one crop straddling the checkerboard window's left edge.
    static func layoutCrops(_ v: CGRect, side: CGFloat, windowEdgeX: CGFloat)
        -> [Crop]
    {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGRect {
            CGRect(
                x: min(max(x - side / 2, v.minX), v.maxX - side),
                y: min(max(y - side / 2, v.minY), v.maxY - side),
                width: side,
                height: side
            ).integral
        }
        return [
            Crop(name: "corner_tl", rect: at(v.minX, v.minY), isEdge: true),
            Crop(name: "corner_tr", rect: at(v.maxX, v.minY), isEdge: true),
            Crop(name: "corner_bl", rect: at(v.minX, v.maxY), isEdge: true),
            Crop(name: "corner_br", rect: at(v.maxX, v.maxY), isEdge: true),
            Crop(
                name: "edge_top",
                rect: at(v.midX * 0.6, v.minY),
                isEdge: true
            ),
            Crop(
                name: "edge_bottom",
                rect: at(v.midX * 0.6, v.maxY),
                isEdge: true
            ),
            Crop(name: "edge_left", rect: at(v.minX, v.midY), isEdge: true),
            Crop(
                name: "edge_right",
                rect: at(v.maxX, v.minY + v.height * 0.2),
                isEdge: true
            ),
            Crop(
                name: "centre",
                rect: at(v.midX * 0.8, v.midY),
                isEdge: false
            ),
            Crop(
                name: "window_edge",
                rect: at(windowEdgeX, v.midY),
                isEdge: false
            ),
        ]
    }

    static func shoot(
        _ label: String,
        _ crops: [Crop],
        _ visible: CGRect,
        _ dir: URL
    ) -> [CGImage?] {
        guard let full = capture(rect: visible) else {
            return crops.map { _ in nil }
        }
        if let thumb = scaled(full, width: 1600) {
            writePNG(thumb, dir.appendingPathComponent("\(label)_full.png"))
        }
        return crops.map { c in
            let img = crop(full, from: visible, to: c.rect)
            if let img {
                writePNG(
                    img,
                    dir.appendingPathComponent("\(label)_\(c.name).png")
                )
            }
            return img
        }
    }

    /// Column profile over the crop's middle third, detrended by a
    /// 15-px moving average so the gradient does not read as a line.
    static func lineProfile(_ img: CGImage) -> [Double] {
        let (w, h, px) = grayPixels(img)
        var col = [Double](repeating: 0, count: w)
        for y in (h / 3)..<(2 * h / 3) {
            for x in 0..<w { col[x] += Double(px[y * w + x]) }
        }
        return col.indices.map { x in
            let lo = max(0, x - 7)
            let hi = min(w - 1, x + 7)
            return col[x] - col[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
    }

    /// Mean |dx| in px from each baseline line (local minimum) to the
    /// nearest current one within 6 px; nil when fewer than half match
    /// (the blur erased the lines, so no refraction is measurable).
    static func displacement(base: [Double], now: [Double]) -> Double? {
        func minima(_ p: [Double]) -> [Int] {
            let sd = (p.map { $0 * $0 }.reduce(0, +) / Double(max(1, p.count)))
                .squareRoot()
            return p.indices.dropFirst().dropLast().filter {
                p[$0] < -1.5 * sd && p[$0] <= p[$0 - 1] && p[$0] <= p[$0 + 1]
            }
        }
        let b = minima(base)
        let n = minima(now)
        guard !b.isEmpty else { return nil }
        let d = b.compactMap { x -> Double? in
            let best = n.map { abs($0 - x) }.min()
            return best.flatMap { $0 <= 6 ? Double($0) : nil }
        }
        return d.count * 2 >= b.count ? d.reduce(0, +) / Double(d.count) : nil
    }

    /// PASS uniform haze: every edge/corner crop's energy ratio (vs no
    /// plate) within 10% of the centre's; displacement < 2 px away from
    /// edges (centre and window-edge crops).
    static func judge(
        _ label: String,
        _ crops: [Crop],
        _ ratio: [Double],
        _ disp: [Double?]
    ) {
        guard let ci = crops.firstIndex(where: { $0.name == "centre" }) else {
            return
        }
        let c = ratio[ci]
        let worst =
            crops.indices.filter { crops[$0].isEdge }
            .map { abs(ratio[$0] - c) / max(c, 1e-6) }.max() ?? .nan
        let inner = crops.indices.filter { !crops[$0].isEdge }.compactMap {
            disp[$0]
        }
        let innerMax = inner.max() ?? 0
        let innerText =
            inner.isEmpty ? "n/a (lines erased)" : fmt(innerMax) + " px"
        verdict(
            args,
            "haze-\(label)",
            worst <= 0.10 && innerMax < 2,
            "worst edge deviation \(fmt(worst * 100))% (≤10), "
                + "inner displacement \(innerText) (<2)"
        )
    }

    static func writeSheet(_ rows: [Row], _ crops: [Crop], _ dir: URL) {
        var h =
            "<!doctype html><meta charset=utf-8><title>KiwiVision P3</title>"
        h += "<style>body{font:12px -apple-system;background:#222;color:#eee}"
        h +=
            "td{vertical-align:top;padding:4px}"
            + "img{width:160px;display:block}</style>"
        h += "<h1>P3 glass haze — \(Date())</h1><table><tr><th>variant</th>"
        h +=
            crops.map { "<th>\($0.name)</th>" }.joined() + "<th>full</th></tr>"
        for r in rows {
            h += "<tr><th>\(r.label)</th>"
            for (i, c) in crops.enumerated() {
                let d = r.disp[i].map { fmt($0) + " px" } ?? "n/a"
                h +=
                    "<td><img src='\(r.label)_\(c.name).png'>"
                    + "e \(fmt(r.energy[i]))"
                h += "<br>ratio \(fmt(r.ratio[i]))<br>disp \(d)</td>"
            }
            h +=
                "<td><img src='\(r.label)_full.png' "
                + "style='width:320px'></td></tr>"
        }
        h += "</table>"
        try? h.write(
            to: dir.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
    }
}
