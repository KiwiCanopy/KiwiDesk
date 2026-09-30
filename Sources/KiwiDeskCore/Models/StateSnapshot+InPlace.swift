import Foundation

/// The session memory only an in-place restart carries across
/// the process swap (#930 ruling 5): written by the in-place
/// stop's capture alone, so after a quit, a crash or a wake the
/// fields are nil and a relaunch starts them fresh, which users
/// rely on. Which stored properties ride here, which ride every
/// snapshot, and which stay behind is `SnapshotCarryCensusTests`'
/// register.
extension StateSnapshot {
    /// One Space's session sizing and its Monocle hold.
    public struct SpaceSession: Codable, Sendable, Equatable {
        public var ratios: SessionRatios
        public var stackWeights: [UInt32: Double]
        public var scrollRest: ScrollRest?
        /// `TilingEngine.monocleShownMembers` (#881): the member
        /// shown while a float holds the focus.
        public var monocleShown: UInt32?

        public init(space: Space, monocleShown: WindowID?) {
            ratios = space.sessionRatios
            stackWeights = Dictionary(
                uniqueKeysWithValues: space.stackWeights.map {
                    ($0.key.raw, $0.value)
                }
            )
            scrollRest = space.scrollRest
            self.monocleShown = monocleShown?.raw
        }

        private enum CodingKeys: String, CodingKey {
            case ratios = "session_ratios"
            case stackWeights = "stack_weights"
            case scrollRest = "scroll_rest"
            case monocleShown = "monocle_shown"
        }
    }

    /// One window's runtime flags: the user float (`true`, else
    /// nil — detection re-derives it, #1810), the sticky scope and
    /// the sticky-reach override.
    public struct WindowSession: Codable, Sendable, Equatable {
        public var floating: Bool?
        public var sticky: StickyScope
        public var stickyReach: Bool?

        public init(
            floating: Bool?,
            sticky: StickyScope,
            stickyReach: Bool?
        ) {
            self.floating = floating
            self.sticky = sticky
            self.stickyReach = stickyReach
        }

        private enum CodingKeys: String, CodingKey {
            case floating, sticky
            case stickyReach = "sticky_reach"
        }
    }
}

extension StateSnapshot {
    /// This snapshot with every in-place payload removed: the
    /// arrangement without the session memory.
    public func droppingSessions() -> StateSnapshot {
        var copy = self
        for index in copy.spaces.indices {
            copy.spaces[index].session = nil
        }
        for index in copy.windows.indices {
            copy.windows[index].session = nil
        }
        return copy
    }

    /// Whether any record carries an in-place payload.
    public var carriesSessions: Bool {
        spaces.contains { $0.session != nil }
            || windows.contains { $0.session != nil }
    }
}

extension StateCoordinator {
    /// The in-place stop's capture (#930): `snapshot()` plus each
    /// Space's and each window's session memory. `monocleShown`
    /// is the engine's hold, which state does not own.
    public func inPlaceSnapshot(
        monocleShown: [SpaceID: WindowID]
    ) -> StateSnapshot {
        var snapshot = snapshot()
        snapshot.spaces = workspaces.allSpaces.map {
            StateSnapshot.SpaceRecord(
                space: $0,
                session: StateSnapshot.SpaceSession(
                    space: $0,
                    monocleShown: monocleShown[$0.id]
                ),
                held: heldRecord(of: $0.id)
            )
        }
        snapshot.windows = snapshot.windows.map { record in
            var record = record
            if let window = windows[record.windowID] {
                record.session = StateSnapshot.WindowSession(
                    floating: userFloated.contains(window.id)
                        ? true : nil,
                    sticky: window.stickyScope,
                    stickyReach: stickyReachOverrides[window.id]
                )
            }
            return record
        }
        return snapshot
    }

    /// Re-applies what `inPlaceSnapshot` added. Space sizing is
    /// written AFTER the record's membership: re-filing a window
    /// drops its stack weight and releases the scroll slot.
    mutating func adoptSession(
        _ record: StateSnapshot.SpaceRecord,
        in space: SpaceID
    ) {
        guard let session = record.session else { return }
        workspaces.withSpace(space) {
            $0.sessionRatios = session.ratios
            $0.stackWeights = Dictionary(
                uniqueKeysWithValues: session.stackWeights.map {
                    (WindowID($0.key), $0.value)
                }
            )
            $0.scrollRest = session.scrollRest
        }
    }

    /// A tracked window's runtime flags; an untracked one keeps
    /// what its late adoption detects.
    mutating func adoptSession(of record: StateSnapshot.WindowRecord) {
        guard let session = record.session,
            windows[record.windowID] != nil
        else { return }
        let id = record.windowID
        // A pre-#1810 `false` was a manual tile, which is gone.
        if session.floating == true {
            setFloating(id, true)
        }
        setSticky(id, session.sticky)
        stickyReachOverrides[id] = session.stickyReach
    }
}
