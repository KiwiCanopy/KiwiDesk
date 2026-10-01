// Counts the WindowServer windows a process owns — all, and on
// screen — and with --by-shape lists them grouped by layer and size.
// A test helper whose on-screen count only climbs is leaking panels
// (#1868, core-boundaries.md). `profile-run.sh` compiles it into
// the per-user temp dir; by hand:
//   swiftc -O window-census.swift \
//     -o "$(getconf DARWIN_USER_TEMP_DIR)kiwidesk-window-census"
// Usage: window-census <pid> [--by-shape]
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count > 1, let pid = Int32(args[1]) else {
    print("usage: window-census <pid> [--by-shape]")
    exit(64)
}
let owned = { (option: CGWindowListOption) -> [[String: Any]] in
    let all =
        CGWindowListCopyWindowInfo(option, kCGNullWindowID)
        as? [[String: Any]] ?? []
    return all.filter {
        ($0[kCGWindowOwnerPID as String] as? Int32) == pid
    }
}
let all = owned(.optionAll)
let onScreen = owned(.optionOnScreenOnly)
print("pid \(pid): all=\(all.count) onScreen=\(onScreen.count)")
if args.contains("--by-shape") {
    var shapes: [String: Int] = [:]
    for window in all {
        let bounds =
            window[kCGWindowBounds as String]
            as? [String: Double] ?? [:]
        let layer = window[kCGWindowLayer as String] ?? "?"
        let width = Int(bounds["Width"] ?? -1)
        let height = Int(bounds["Height"] ?? -1)
        shapes["layer \(layer) \(width)x\(height)", default: 0] += 1
    }
    for (shape, count) in shapes.sorted(by: { $0.value > $1.value })
        .prefix(15)
    {
        print("  \(count)  \(shape)")
    }
}
