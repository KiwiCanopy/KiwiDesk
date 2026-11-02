import Foundation

/// The session memory only an in-place restart carries across
/// the process swap (#930 ruling 5): written by the in-place
/// stop's capture alone, so after a quit, a crash or a wake the
/// fields are nil and a relaunch starts them fresh, which users
/// rely on. The hand float is not here: every stop carries it
/// (#1864). Which stored properties ride here, which ride every
/// snapshot or every stop, and which stay behind is
/// `SnapshotCarryCensusTests`' register.
extension StateSnapshot {
    /// One Space's session sizing and its Monocle hold.
    public struct SpaceSession: Codable, Sendable, Equatable {
        /// The shared entry for a Desktop no reading names (#2921
        /// ruling 3). A build before 4.2.0 wrote this key alone, as
        /// the Space's one entry: such a record has no
        /// `desktopRatios`, and the restore adopts it on the Desktop
        /// shown (`isOneEntry`).
        public var ratios: SessionRatios
        /// The sizes per named Desktop (#2921), by native id; every
        /// capture writes the list, an empty one included.
        public var desktopRatios: [DesktopRatios]?
        public var stackWeights: [UInt32: Double]
        public var scrollRest: ScrollRest?
        /// `TilingEngine.monocleShownMembers` (#881): the member
        /// shown while a float holds the focus.
        public var monocleShown: UInt32?
        /// `Space.maximized` (#2448): an in-place restart moves
        /// nothing, so the maximized window stays filling its screen.
        public var maximized: UInt32?
        /// `Space.runHeads` and `runTails` (#2235): where each
        /// scrolled zone rests.
        public var runHeads: [UInt32]?
        public var runTails: [UInt32]?

        public init(
            space: Space,
            ratios entries: [SkyLight.SpaceID?: SessionRatios],
            monocleShown: WindowID?
        ) {
            ratios = entries[nil] ?? SessionRatios()
            let named = entries.compactMap { desktop, ratios in
                desktop.map { DesktopRatios(desktop: $0, ratios: ratios) }
            }
            desktopRatios = named.sorted { $0.desktop < $1.desktop }
            stackWeights = Dictionary(
                uniqueKeysWithValues: space.stackWeights.map {
                    ($0.key.raw, $0.value)
                }
            )
            scrollRest = space.scrollRest
            self.monocleShown = monocleShown?.raw
            maximized = space.maximized?.raw
            runHeads =
                space.runHeads.isEmpty
                ? nil : space.runHeads.map(\.raw).sorted()
            runTails =
                space.runTails.isEmpty
                ? nil : space.runTails.map(\.raw).sorted()
        }

        /// A record a build before #2921 wrote: one entry per Space.
        public var isOneEntry: Bool { desktopRatios == nil }

        /// Every entry, the shared one under nil.
        public var ratioEntries: [SkyLight.SpaceID?: SessionRatios] {
            var out: [SkyLight.SpaceID?: SessionRatios] = [nil: ratios]
            for entry in desktopRatios ?? [] {
                out[entry.desktop] = entry.ratios
            }
            return out
        }

        private enum CodingKeys: String, CodingKey {
            case ratios = "session_ratios"
            case desktopRatios = "desktop_ratios"
            case stackWeights = "stack_weights"
            case scrollRest = "scroll_rest"
            case monocleShown = "monocle_shown"
            case maximized
            case runHeads = "run_heads"
            case runTails = "run_tails"
        }
    }

    /// One named Desktop's sizes for a Space (#2921).
    public struct DesktopRatios: Codable, Sendable, Equatable {
        public var desktop: SkyLight.SpaceID
        public var ratios: SessionRatios

        public init(desktop: SkyLight.SpaceID, ratios: SessionRatios) {
            self.desktop = desktop
            self.ratios = ratios
        }

        private enum CodingKeys: String, CodingKey {
            case desktop
            case ratios = "session_ratios"
        }
    }

    /// One window's runtime flags: the sticky scope and the
    /// sticky-reach override. The hand float rides the record
    /// itself, on every stop (#1864, `StateSnapshot+StopFloats`).
    public struct WindowSession: Codable, Sendable, Equatable {
        public var sticky: StickyScope
        public var stickyReach: Bool?

        public init(sticky: StickyScope, stickyReach: Bool?) {
            self.sticky = sticky
            self.stickyReach = stickyReach
        }

        private enum CodingKeys: String, CodingKey {
            case sticky
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
    /// is the engine's hold and `ratios` each Space's per-Desktop
    /// sizes (#2921), which state does not own.
    public func inPlaceSnapshot(
        monocleShown: [SpaceID: WindowID],
        ratios: (SpaceID) -> [SkyLight.SpaceID?: SessionRatios]
    ) -> StateSnapshot {
        var snapshot = snapshot()
        snapshot.spaces = workspaces.allSpaces.map {
            spaceRecord(
                of: $0,
                session: StateSnapshot.SpaceSession(
                    space: $0,
                    ratios: ratios($0.id),
                    monocleShown: monocleShown[$0.id]
                )
            )
        }
        snapshot.windows = snapshot.windows.map { record in
            var record = record
            if let window = windows[record.windowID] {
                record.session = StateSnapshot.WindowSession(
                    sticky: window.stickyScope,
                    stickyReach: stickyReachOverrides[window.id]
                )
            }
            return record
        }
        snapshot.pocket = pocket
        return snapshot
    }

    /// Re-applies what `inPlaceSnapshot` added. Space sizing is
    /// written AFTER the record's membership: re-filing a window
    /// drops its stack weight and releases the scroll slot. The
    /// per-Desktop ratios are `KiwiCore.restore`'s to adopt.
    mutating func adoptSession(
        _ record: StateSnapshot.SpaceRecord,
        in space: SpaceID
    ) {
        guard let session = record.session else { return }
        workspaces.withSpace(space) {
            $0.stackWeights = Dictionary(
                uniqueKeysWithValues: session.stackWeights.map {
                    (WindowID($0.key), $0.value)
                }
            )
            $0.scrollRest = session.scrollRest
            $0.runHeads = Set(
                (session.runHeads ?? []).map { WindowID($0) }
            )
            $0.runTails = Set(
                (session.runTails ?? []).map { WindowID($0) }
            )
            if let raw = session.maximized,
                $0.windows.contains(WindowID(raw))
            {
                $0.maximized = WindowID(raw)
            }
        }
    }

    /// A tracked window's runtime flags; an untracked one keeps
    /// what its late adoption detects.
    mutating func adoptSession(of record: StateSnapshot.WindowRecord) {
        guard let session = record.session,
            windows[record.windowID] != nil
        else { return }
        let id = record.windowID
        setSticky(id, session.sticky)
        stickyReachOverrides[id] = session.stickyReach
    }

    /// Takes back an in-place capture's pocket (#2446). A window the
    /// boot scan already filed leaves its Space again; a slow app's
    /// window not yet tracked is re-adopted unfiled by the create
    /// fold, and a press finds an exited app's slot and empties it.
    mutating func adoptPocket(_ slots: [PocketSlot]) {
        guard !slots.isEmpty else { return }
        pocket = slots
        for slot in slots where readoptPocketWindow(slot.window) {
            workspaces.remove(slot.window)
        }
    }
}
