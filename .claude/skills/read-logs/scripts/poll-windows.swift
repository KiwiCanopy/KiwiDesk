// On-screen windows of one app, printed only on change, with the
// age of the previous line so a burst is not misread as the
// previous event's after-effect.
// Usage: swiftc -O poll-windows.swift -o poll && ./poll "<owner name>"
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.dropFirst().first ?? ""
var last = ""
var lastAt = Date()
while true {
    let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
        as? [[String: Any]] ?? []
    let lines = list.compactMap { w -> String? in
        guard (w["kCGWindowOwnerName"] as? String) == owner,
            (w["kCGWindowIsOnscreen"] as? Bool) == true,
            let b = w["kCGWindowBounds"] as? [String: Any]
        else { return nil }
        let id = w["kCGWindowNumber"] ?? "?"
        let layer = w["kCGWindowLayer"] ?? "?"
        let name = w["kCGWindowName"] as? String ?? ""
        return "w\(id) L\(layer) \(b["X"]!),\(b["Y"]!) "
            + "\(b["Width"]!)x\(b["Height"]!) '\(name)'"
    }
    let now = Date()
    let joined = lines.joined(separator: " | ")
    if joined != last {
        let stamp = DateFormatter.localizedString(
            from: now, dateStyle: .none, timeStyle: .medium)
        let age = String(format: "%.2f", now.timeIntervalSince(lastAt))
        print("\(stamp) (+\(age)s) \(joined)")
        fflush(stdout)
        last = joined
        lastAt = now
    }
    usleep(150_000)
}
