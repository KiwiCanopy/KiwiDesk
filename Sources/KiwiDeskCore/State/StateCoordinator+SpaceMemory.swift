import Foundation

/// Space memory accessors and provenance tracking (`StateCoordinator`, #1010).
extension StateCoordinator {
    /// Tracks origin and provenance of remembered window space associations
    /// (`StateSnapshot.adopt`, #1010).
    enum SpaceMemory: Sendable, Equatable {
        /// Window departure observed by destroy fold.
        case departed(SpaceID)
        /// Filed from session snapshot before window discovery.
        case restored(SpaceID)

        var space: SpaceID {
            switch self {
            case .departed(let space), .restored(let space):
                return space
            }
        }
    }

    /// Records restored space association for untracked window
    /// (`rememberedSpaces`, #1010).
    mutating func remember(_ id: WindowID, in space: SpaceID) {
        rememberedSpaces[id] = .restored(space)
    }

    /// Records the slot `id` holds as it departs `space` (#1207):
    /// its index today, raised past every sibling that already
    /// departed this space ahead of it — a burst folds one window
    /// at a time, so the index alone would read 0 for each.
    mutating func rememberDepartedSlot(
        of id: WindowID,
        in space: SpaceID
    ) {
        guard
            var rank = workspaces[space]?.windows.firstIndex(of: id)
        else { return }
        let departed = departedSlots.filter { entry in
            entry.key != id
                && windows[entry.key] == nil
                && rememberedSpaces[entry.key] == .departed(space)
        }
        for sibling in departed.values.sorted() where sibling <= rank {
            rank += 1
        }
        departedSlots[id] = rank
    }

    /// Clears all remembered space associations (`CGWindowID`, #634).
    public mutating func forgetRememberedSpaces() {
        rememberedSpaces = [:]
        departedSlots = [:]
    }

    /// Retrieves remembered space identifier for untracked window.
    func rememberedSpace(of id: WindowID) -> SpaceID? {
        rememberedSpaces[id]?.space
    }
}
