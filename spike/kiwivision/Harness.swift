// KiwiVision v0 probes (#2103) — shared harness: process, args,
// window stack, timing, CSV, dlsym. Plates and activation live in
// HarnessPlates.swift, pixels in HarnessPixels.swift. A spike: never
// merged, never lint-gated.
// Build every probe with `-parse-as-library` (each has its own @main).
import AppKit
import CoreGraphics
import Foundation

// MARK: - Arguments and output

/// argv[1] is the output directory; flags follow.
struct Args {
    let probe: String
    let out: URL
    let raw: [String]

    init(probe: String) {
        self.probe = probe
        raw = CommandLine.arguments
        guard raw.count > 1, !raw[1].hasPrefix("--") else {
            print("usage: \(raw.first ?? probe) <output-dir> [flags]")
            exit(2)
        }
        out = URL(fileURLWithPath: raw[1], isDirectory: true)
        try? FileManager.default.createDirectory(
            at: out,
            withIntermediateDirectories: true
        )
    }

    func has(_ flag: String) -> Bool { raw.contains(flag) }

    func value(_ flag: String) -> String? {
        guard let i = raw.firstIndex(of: flag), i + 1 < raw.count
        else { return nil }
        return raw[i + 1]
    }

    func int(_ flag: String, _ fallback: Int) -> Int {
        value(flag).flatMap(Int.init) ?? fallback
    }

    func url(_ name: String) -> URL { out.appendingPathComponent(name) }
}

/// Appends one line per row, so a crashed run keeps what it measured.
final class CSV {
    private let handle: FileHandle?

    init(_ url: URL, header: [String]) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        row(header)
    }

    func row(_ fields: [Any]) {
        let line =
            fields.map { field -> String in
                if let d = field as? Double {
                    return String(format: "%.4f", d)
                }
                if let c = field as? CGFloat {
                    return String(format: "%.4f", Double(c))
                }
                return "\(field)".replacingOccurrences(of: ",", with: ";")
            }.joined(separator: ",") + "\n"
        handle?.write(line.data(using: .utf8)!)
    }
}

/// Prints a verdict line and appends it to <out>/summary.txt.
func verdict(_ args: Args, _ name: String, _ pass: Bool?, _ detail: String) {
    let tag = pass.map { $0 ? "PASS" : "FAIL" } ?? "INFO"
    let line = "[\(args.probe)] \(tag) \(name) — \(detail)"
    print(line)
    let url = args.url("summary.txt")
    if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    if let h = try? FileHandle(forWritingTo: url) {
        _ = try? h.seekToEnd()
        h.write((line + "\n").data(using: .utf8)!)
        try? h.close()
    }
}

// MARK: - App and run loop

/// An accessory app: no Dock icon, never steals activation by itself.
@MainActor
func bootApp() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.finishLaunching()
}

/// CLI tools must pump, or AppKit and NSWorkspace state never update.
@MainActor
func pump(_ seconds: Double) {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
}

// MARK: - Timing and stats

func nowNS() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
func ms(since start: UInt64) -> Double { Double(nowNS() - start) / 1e6 }

/// Runs `body` and returns its wall time in ms (main thread).
@MainActor
@discardableResult
func timed(_ body: () -> Void) -> Double {
    let start = nowNS()
    body()
    return ms(since: start)
}

func percentile(_ xs: [Double], _ p: Double) -> Double {
    guard !xs.isEmpty else { return .nan }
    let s = xs.sorted()
    let i = min(
        s.count - 1,
        max(0, Int((p / 100 * Double(s.count)).rounded(.up)) - 1)
    )
    return s[i]
}

func fmt(_ x: Double) -> String { String(format: "%.2f", x) }

// MARK: - Window stack (front to back)

struct WinInfo {
    let number: Int
    let pid: pid_t
    let layer: Int
    let bounds: CGRect  // CG global, top-left origin
    let owner: String
}

/// Every on-screen window, front to back.
func windowList() -> [WinInfo] {
    guard
        let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]]
    else { return [] }
    return raw.compactMap { d in
        guard let n = d[kCGWindowNumber as String] as? Int,
            let pid = d[kCGWindowOwnerPID as String] as? Int,
            let layer = d[kCGWindowLayer as String] as? Int
        else { return nil }
        var rect = CGRect.zero
        if let b = d[kCGWindowBounds as String] as? NSDictionary,
            let r = CGRect(dictionaryRepresentation: b as CFDictionary)
        {
            rect = r
        }
        let owner = d[kCGWindowOwnerName as String] as? String ?? "?"
        return WinInfo(
            number: n,
            pid: pid_t(pid),
            layer: layer,
            bounds: rect,
            owner: owner
        )
    }
}

/// Front-to-back on-screen window numbers.
func stack() -> [Int] { windowList().map(\.number) }

/// The app's frontmost normal-layer window big enough to be a document.
func frontWindow(ofPID pid: pid_t) -> WinInfo? {
    windowList().first {
        $0.pid == pid && $0.layer == 0
            && $0.bounds.width > 80 && $0.bounds.height > 80
    }
}

// MARK: - Coordinates

/// AppKit (bottom-left, primary screen) <-> CG (top-left). Symmetric.
@MainActor
func flipRect(_ r: CGRect) -> CGRect {
    let h = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
}

// MARK: - Private symbols (dlsym only — os-private-apis.md)

/// Resolves a SkyLight symbol, nil when absent. Never linked.
func skyLightSymbol<T>(_ name: String, as: T.Type) -> T? {
    guard
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY
        ), let sym = dlsym(handle, name)
    else { return nil }
    return unsafeBitCast(sym, to: T.self)
}
