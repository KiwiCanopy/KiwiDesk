import Foundation

/// The window→space memory: where a window belongs while
/// KiwiDesk is not tracking it. Split from `StateCoordinator`
/// for the file ceiling (§2.1), like the event folds.
///
/// The map itself stays declared beside the other state (its
/// doc comment there says what it is for); this file owns the
/// vocabulary and the accessors — including the distinction the
/// #1010 arrival rule turns on, which is not WHERE the window
/// belongs but WHO said so.
extension StateCoordinator {
    /// Where a window→space association came from (#1010).
    /// The space is the same fact either way; what differs is
    /// whether KiwiDesk WATCHED the window leave, which is the
    /// only case carrying a user's recent intent about where it
    /// belongs — so the cross-screen arrival rule asks for it
    /// and every other reader takes `space` and ignores the
    /// case.
    enum SpaceMemory: Sendable, Equatable {
        /// The destroy fold watched the window go: a Desktop
        /// switch, an app hidden with ⌘H, a close.
        case departed(SpaceID)
        /// KiwiDesk filed it from its own snapshot for a window
        /// it is not tracking yet (`StateSnapshot.adopt`) — a
        /// record of where the window BELONGS, never an
        /// observation of it moving.
        case restored(SpaceID)

        var space: SpaceID {
            switch self {
            case .departed(let space), .restored(let space):
                return space
            }
        }
    }

    /// Notes where a currently-untracked window belongs (see
    /// rememberedSpaces; used by session restore). `.restored`,
    /// never `.departed`: nothing was observed leaving — this is
    /// KiwiDesk's own filing, which is why the #1010 arrival
    /// rule leaves it alone.
    mutating func remember(_ id: WindowID, in space: SpaceID) {
        rememberedSpaces[id] = .restored(space)
    }

    /// Drops every remembered window→space association — the
    /// tier-1 escape hatch's in-memory half (#634): entries for
    /// windows that no longer exist are the ids a recycled
    /// `CGWindowID` can inherit, teleporting an unrelated new
    /// window into an old space. Live windows are unaffected;
    /// one that leaves and returns lands in the active space
    /// once, like any new window.
    public mutating func forgetRememberedSpaces() {
        rememberedSpaces = [:]
    }

    /// Where an untracked window will be filed once tracked.
    /// Session restore fills this before slow-AX apps list
    /// their windows, so startup can land on the right space
    /// even when the window itself is not tracked yet.
    func rememberedSpace(of id: WindowID) -> SpaceID? {
        rememberedSpaces[id]?.space
    }
}
