// KiwiVision v0 probes (#2103) — plates (the ring's panel recipe),
// the ring stand-in, app activation and the GPU busy reading.
import AppKit
import Foundation

// MARK: - Plates

enum Blur {
    case none
    case effect(NSVisualEffectView.Material, NSVisualEffectView.State)
    case glass(regular: Bool, tint: NSColor?)
    case solid(NSColor)
}

struct PlateSpec {
    var blur: Blur = .none
    var dim: CGFloat = 0  // black overlay alpha, above the blur
    var blurAlpha: CGFloat = 1  // the blur view's own alphaValue
    var panelAlpha: CGFloat = 1  // the whole panel's alphaValue
}

final class ProbePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A borderless non-activating panel with the ring's recipe
/// (`AppKitBorderOverlay.makePanel`): normal level, `.transient`,
/// `.canJoinAllSpaces`, click-through. `frame` is AppKit coordinates.
@MainActor
func makePanel(frame: CGRect) -> NSPanel {
    let panel = ProbePanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.level = .normal
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    panel.collectionBehavior = [
        .canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle,
    ]
    return panel
}

@MainActor
func makePlate(frame: CGRect, spec: PlateSpec) -> NSPanel {
    let panel = makePanel(frame: frame)
    configure(panel, spec: spec)
    return panel
}

/// Rebuilds the plate's content for `spec`; keeps the window number.
@MainActor
func configure(_ panel: NSPanel, spec: PlateSpec) {
    let bounds = CGRect(origin: .zero, size: panel.frame.size)
    let root = NSView(frame: bounds)
    root.wantsLayer = true
    var blurView: NSView?
    switch spec.blur {
    case .none:
        break
    case .effect(let material, let state):
        let v = NSVisualEffectView(frame: bounds)
        v.blendingMode = .behindWindow
        v.material = material
        v.state = state
        blurView = v
    case .glass(let regular, let tint):
        if #available(macOS 26, *) {
            let g = NSGlassEffectView(frame: bounds)
            g.style = regular ? .regular : .clear
            g.cornerRadius = 0
            // UNVERIFIED: `tintColor` spelling (bars.md names it as
            // NSGlassEffectView.tintColor; GlassPlate never sets it).
            g.tintColor = tint
            blurView = g
        } else {
            print("glass needs macOS 26; plate left without blur")
        }
    case .solid(let color):
        let v = NSView(frame: bounds)
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        blurView = v
    }
    if let blurView {
        blurView.autoresizingMask = [.width, .height]
        blurView.alphaValue = spec.blurAlpha
        root.addSubview(blurView)
    }
    if spec.dim > 0 {
        let dim = NSView(frame: bounds)
        dim.wantsLayer = true
        dim.layer?.backgroundColor =
            NSColor.black.withAlphaComponent(spec.dim).cgColor
        dim.autoresizingMask = [.width, .height]
        root.addSubview(dim)
    }
    panel.contentView = root
    panel.alphaValue = spec.panelAlpha
}

/// The focus ring's stand-in: a hollow 4-pt green frame.
@MainActor
func makeRingStandIn(
    frame: CGRect = CGRect(x: 0, y: 0, width: 200, height: 200)
)
    -> NSPanel
{
    let panel = makePanel(frame: frame)
    let v = NSView(frame: CGRect(origin: .zero, size: frame.size))
    v.wantsLayer = true
    v.layer?.borderColor = NSColor.systemGreen.cgColor
    v.layer?.borderWidth = 4
    v.autoresizingMask = [.width, .height]
    panel.contentView = v
    return panel
}

// MARK: - Activation and GPU

/// Activates an app: `NSRunningApplication.activate()` first, then
/// LaunchServices (`openApplication`, activates) if macOS's cooperative
/// activation refused it. Returns whether it became frontmost and how.
@MainActor
func activate(bundleID: String, timeout: Double = 1.5)
    -> (ok: Bool, via: String, ms: Double)
{
    let start = nowNS()
    let isFront = {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
    }
    // UNVERIFIED: whether macOS 27's cooperative activation honours
    // activate() from a background CLI; the fallback covers a refusal.
    if let app =
        NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleID).first
    {
        _ = app.activate()
        while ms(since: start) < 400 {
            if isFront() { return (true, "activate", ms(since: start)) }
            pump(0.01)
        }
    }
    guard
        let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
    else { return (false, "missing", ms(since: start)) }
    let cfg = NSWorkspace.OpenConfiguration()
    cfg.activates = true
    NSWorkspace.shared.openApplication(
        at: url,
        configuration: cfg,
        completionHandler: nil
    )
    while ms(since: start) < timeout * 1000 {
        if isFront() { return (true, "openApplication", ms(since: start)) }
        pump(0.01)
    }
    return (false, "timeout", ms(since: start))
}

func pid(of bundleID: String) -> pid_t? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .first?.processIdentifier
}

/// ioreg's GPU Device Utilization %, the measure-work skill's reading.
func gpuBusy() -> Int? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
    p.arguments = ["-r", "-d", "1", "-c", "IOAccelerator"]
    let pipe = Pipe()
    p.standardOutput = pipe
    guard (try? p.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let text = String(decoding: data, as: UTF8.self)
    guard let r = text.range(of: "\"Device Utilization %\"=") else {
        return nil
    }
    return Int(text[r.upperBound...].prefix { $0.isNumber })
}
