import AppKit

/// A Core plate's ground where no Liquid Glass draws: the
/// behind-window blur nearest the shortcuts panel's
/// `.regularMaterial` (owner, device, #1956), wearing the Fill
/// flat beneath its content under "Tint KiwiHub and plates"
/// (#2569 ▸ amendment). The Space-switch plates and the brief
/// pocket's plate both build theirs here.
@MainActor
enum FrostPlate {
    /// The wash's place in the material, found by identifier.
    private static let wash = NSUserInterfaceItemIdentifier(
        "KiwiDesk.FrostPlate.wash"
    )

    /// The material hosting `content`, wearing `fill`.
    static func make(
        content: NSView,
        fill: FrostFill?
    ) -> NSVisualEffectView {
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.masksToBounds = true
        if let fill {
            let view = NSView(frame: material.bounds)
            view.identifier = wash
            view.autoresizingMask = [.width, .height]
            view.wantsLayer = true
            view.layer?.backgroundColor = Self.colour(fill).cgColor
            material.addSubview(view)
            GlassTint.pinFrost(material, to: fill.pin)
        }
        material.addSubview(content)
        return material
    }

    /// The colour `material` wears, nil where it wears none.
    static func washColour(of material: NSView) -> NSColor? {
        material.subviews
            .first { $0.identifier == wash }?
            .layer?.backgroundColor
            .flatMap { NSColor(cgColor: $0) }
    }

    private static func colour(_ fill: FrostFill) -> NSColor {
        NSColor(
            srgbRed: fill.red,
            green: fill.green,
            blue: fill.blue,
            alpha: fill.alpha
        )
    }
}
