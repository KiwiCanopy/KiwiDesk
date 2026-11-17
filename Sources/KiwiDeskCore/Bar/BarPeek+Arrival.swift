import AppKit

/// A section that joins its strip lands under a resting pointer
/// that asked for nothing, and AppKit then sends its items no
/// entry and no exit (#3388): the placement's hover re-read finds
/// them under the pointer, and a peek opened from it stood until
/// the pointer crossed the item. Inside `rereading(arrived:_:)` a
/// reading on such a section opens and swaps in no peek; it still
/// closes one, and the pointer's next move opens it as ever.
extension BarPeek {
    /// Runs the placement's hover re-read with `roots` — the
    /// section roots that joined their strip in this placement —
    /// opening no peek on them.
    func rereading(arrived roots: [NSView], _ body: () -> Void) {
        arrived = roots
        defer { arrived = [] }
        body()
    }

    /// Whether `anchor` sits in a section that just arrived.
    func arrives(_ anchor: NSView) -> Bool {
        arrived.contains { anchor.isDescendant(of: $0) }
    }
}
