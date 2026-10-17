import SwiftUI

/// The face of a button that opens a pop-up of its own — the Font
/// and app pickers' triggers — drawn as the native pop-up menu
/// beside it reads (owner ruling 2026-10-17): a capsule on the
/// button-chip fill ladder, lifting under the pointer as a custom
/// hit area does, with no edge (`ChipFace`). Reached only through
/// `settingsPopUpTrigger()`, which pairs the neutral label
/// (`PopUpTriggerTests`).
struct PopUpTriggerStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ChipFace(configuration: configuration, popUp: true)
    }
}
