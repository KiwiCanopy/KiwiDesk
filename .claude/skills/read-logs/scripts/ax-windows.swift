// One app's AX windows: role, subrole, main, fullscreen, frame.
// Needs the host terminal to hold the Accessibility grant.
// Usage: swift ax-windows.swift <pid>
import AppKit
import ApplicationServices

print("AX trusted:", AXIsProcessTrusted())
guard let pid = CommandLine.arguments.dropFirst().first.flatMap(Int32.init)
else { fatalError("usage: swift ax-windows.swift <pid>") }
let app = AXUIElementCreateApplication(pid)
var value: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
for window in (value as? [AXUIElement]) ?? [] {
    func read(_ key: String) -> String {
        var out: CFTypeRef?
        AXUIElementCopyAttributeValue(window, key as CFString, &out)
        return out.map { "\($0)" } ?? "nil"
    }
    print(
        read("AXTitle"), "|", read("AXRole"), read("AXSubrole"),
        "| main", read("AXMain"), "| fullscreen", read("AXFullScreen"),
        "|", read("AXPosition"), read("AXSize"))
}
