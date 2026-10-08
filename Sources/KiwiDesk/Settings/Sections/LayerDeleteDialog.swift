import KiwiDeskCore
import SwiftUI

/// The layer delete's question (#2022): it names the layer and how
/// many shortcuts go, and where another profile has the layer it
/// asks how far. Cancel is the default, so a reflex Return deletes
/// nothing.
struct LayerDeleteDialog: ViewModifier {
    @Binding var request: LayerDeleteRequest?
    let delete: (RuleRemoval) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            LayerReachWords.deleteTitle(request?.layer ?? ""),
            isPresented: Binding(
                get: { request != nil },
                set: { if !$0 { request = nil } }
            ),
            titleVisibility: .visible,
            presenting: request
        ) { request in
            if let reading = request.reading,
                LayerReachWords.isShared(reading)
            {
                Button(
                    LayerReachWords.deleteHere(reading),
                    role: .destructive
                ) { delete(.here) }
                Button(
                    LayerReachWords.deleteEverywhere(reading),
                    role: .destructive
                ) { delete(.everywhere) }
            } else {
                Button(LayerReachWords.delete, role: .destructive) {
                    delete(.everywhere)
                }
            }
            Button(
                L("shortcuts.layer_delete.cancel", "Cancel"),
                role: .cancel
            ) {}
            .keyboardShortcut(.defaultAction)
        } message: { request in
            Text(LayerReachWords.deleteMessage(request.count, request.reading))
        }
    }
}

/// The delete dialog's request, built from ONE layer (#843).
struct LayerDeleteRequest: Identifiable {
    var id: String { layer }
    let layer: String
    let count: Int
    let reading: RuleReachReading?
}
