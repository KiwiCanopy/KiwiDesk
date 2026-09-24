import Foundation

/// A shelf section's own glass hosting (#407, #1517): the plate
/// under both sections is the shelf's (`ShelfOverlay`), so a
/// section hosts glass only per item, in Boxed. One `resolve` per
/// render feeds one dispatch, so the teardown invariant lives in
/// ONE place.
enum GlassHosting: Equatable {
    /// No glass of the section's own: items on the shelf's plate,
    /// or a solid box each.
    case plainPlate
    /// Boxed glass per item.
    case boxGlass
    /// Unsupported OS version (below macOS 26) fallback.
    case none

    /// Resolves the single hosting mode for a section render — one
    /// authority so the two sections can't drift (#407).
    static func resolve(
        available: Bool,
        glassEnabled: Bool,
        boxed: Bool
    ) -> GlassHosting {
        guard available else { return .none }
        return glassEnabled && boxed ? .boxGlass : .plainPlate
    }
}
