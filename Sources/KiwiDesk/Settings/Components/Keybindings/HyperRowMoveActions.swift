import KiwiDeskCore
import SwiftUI

/// A shortcut row's Move to Hyper (#2420) on its `rowActions` menu.
/// Absent where the row cannot move (no Hyper key, already on `✦`,
/// app chrome, off both bases); greyed with the holder named where
/// another row holds the target.
struct HyperRowMoveActions: ViewModifier {
    let move: HyperShortcutMove.RowMove?
    /// The holder as its own row names it (#2111).
    let name: (KeyBinding) -> String
    /// Re-judges the move against the rows at the click.
    let onMove: () -> Void

    /// Whether rows offer the move at all: a move with no key writes
    /// a chord nothing can press. The Hyper key row's hint reads it.
    static func isOffered(key: HyperSourceKey?) -> Bool { key != nil }

    /// One structure whether or not the row can move, so the move
    /// retiring its own item keeps the row's identity and focus.
    func body(content: Content) -> some View {
        content.rowActions(offered: move != nil) { actions }
    }

    @ViewBuilder private var actions: some View {
        switch move {
        case nil:
            EmptyView()
        case .move:
            Button(HyperMoveWords.rowAction, action: onMove)
        case .taken(let to, let holder):
            Button(HyperMoveWords.rowAction) {}
                .disabled(true)
            Button {
            } label: {
                let text = HyperMoveWords.taken(
                    chord: HyperMoveWords.chord(to),
                    by: name(holder)
                )
                Text(text)
                    .accessibilityLabel(HyperMoveWords.spoken(text))
            }
            .disabled(true)
        }
    }
}
