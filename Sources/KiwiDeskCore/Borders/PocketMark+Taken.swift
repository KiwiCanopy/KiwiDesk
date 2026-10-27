import AppKit

/// The pocket's "already taken" glyph (#2675): the badge with a
/// `nosign` knocked into its lower corner, so the refusal pill reads
/// as the pocket refused. Named by a sentinel the pill's symbol slot
/// resolves, as `StateBadgeView.pocketName` does.
extension PocketMark {
    static let takenName = "kiwidesk.pocket.taken"

    /// The glyph `name` stands for, or nil for a system symbol.
    static func pillImage(named name: String, size: CGFloat) -> NSImage? {
        guard name == takenName else { return nil }
        return NSImage(
            size: NSSize(width: size, height: size),
            flipped: true
        ) { rect in
            PocketMark.badge.image(size: rect.width, ink: .labelColor)
                .draw(in: rect)
            let side = rect.width * 0.5
            let corner = NSRect(
                x: rect.maxX - side,
                y: rect.maxY - side,
                width: side,
                height: side
            )
            // Knocked out first, so the sign reads on the pocket.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: corner.insetBy(dx: -0.75, dy: -0.75)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            let sign = NSImage(
                systemSymbolName: "nosign",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: side,
                    weight: .bold
                ).applying(
                    NSImage.SymbolConfiguration(
                        paletteColors: [.secondaryLabelColor]
                    )
                )
            )
            sign?.draw(in: corner)
            return true
        }
    }
}
