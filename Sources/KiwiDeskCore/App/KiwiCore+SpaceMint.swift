import Foundation

/// The number a newly minted Space takes (#1790): the smallest one
/// nothing already names — a live Space, a window that will come
/// back to a Space of that number, or a declaration a later apply
/// re-creates. The empty-display heal and a Space chip's New Space
/// both take it here (profiles.md ▸ A minted Space avoids every
/// name).
extension KiwiCore {
    func mintedSpaceNumber() -> SpaceID {
        var taken = Set(state.workspaces.allSpaces.map(\.id))
        taken.formUnion(state.rememberedSpaces.values.map(\.space))
        taken.formUnion(profiles.active?.declaredSpaces ?? [])
        taken.formUnion(profiles.standard?.spaces ?? [])
        taken.formUnion(initDeclaredSpaces)
        // A number whose old shortcuts are still to go (#1827).
        taken.formUnion(state.owedShortcutDrops)
        return SpaceID.smallestFreeNumber(among: taken)
    }
}
