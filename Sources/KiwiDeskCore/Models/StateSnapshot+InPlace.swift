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
        /// The sizes the Space draws at the capture. A build before
        /// 4.2.0 kept this one set per Space and reads it back; this
        /// build reads it only from such a record (`oneEntry`).
        public var ratios: SessionRatios
        /// Every Desktop's and arrangement's sizes (#2921); every
        /// capture writes the list, an empty one included.
        public var desktopRatios: [DesktopRatios]?
        public var stackWeights: [UInt32: Double]
        /// `Space.runSizes` (#2709); absent from a build before
        /// 4.2.0 and while no window carries one.
        public var runSizes: [UInt32: RunSize]?
        public var scrollRest: ScrollRest?
        /// `TilingEngine.monocleShownMembers` (#881): the member
        /// shown while a float holds the focus.
        public var monocleShown: UInt32?
        /// `Space.maximized` (#2448): an in-place restart moves
        /// nothing, so the maximized window stays filling its screen.
        public var maximized: UInt32?
        /// `Space.maximized`'s shape (#3062); absent for a full Maximize
        /// and from a build before it, either decoding as full.
        public var maximizeShape: MaximizeShape?
        /// Whether that Maximize follows focus (#3063); absent when it
        /// does not and from a build before it, either decoding as no
        /// follow.
        public var maximizeFollows: Bool?
        /// `Space.runHeads` and `runTails` (#2235): where each
        /// scrolled zone rests.
        public var runHeads: [UInt32]?
        public var runTails: [UInt32]?

        public init(
            space: Space,
            ratios sizes: SessionSizing,
            monocleShown: WindowID?
        ) {
            ratios = sizes.drawn
            desktopRatios = sizes.entries
                .map {
                    DesktopRatios(
                        desktop: $0.key.desktop,
                        arrangement: $0.key.arrangement,
                        ratios: $0.value
                    )
                }
                .sorted { $0.order < $1.order }
            stackWeights = Dictionary(
                uniqueKeysWithValues: space.stackWeights.map {
                    ($0.key.raw, $0.value)
                }
            )
            runSizes =
                space.runSizes.isEmpty
                ? nil
                : Dictionary(
                    uniqueKeysWithValues: space.runSizes.map {
                        ($0.key.raw, $0.value)
                    }
                )
            scrollRest = space.scrollRest
            self.monocleShown = monocleShown?.raw
            maximized = space.maximized?.window.raw
            maximizeShape =
                space.maximized.flatMap { $0.shape == .full ? nil : $0.shape }
            maximizeFollows = space.maximized?.follows == true ? true : nil
            runHeads =
                space.runHeads.isEmpty
                ? nil : space.runHeads.map(\.raw).sorted()
            runTails =
                space.runTails.isEmpty
                ? nil : space.runTails.map(\.raw).sorted()
        }

        /// A record a build before #2921 wrote: its one set per
        /// Space, else nil.
        public var oneEntry: SessionRatios? {
            desktopRatios == nil ? ratios : nil
        }

        /// Every entry the list carries.
        public var ratioEntries: [SessionSizingKey: SessionRatios] {
            var out: [SessionSizingKey: SessionRatios] = [:]
            for entry in desktopRatios ?? [] {
                out[
                    SessionSizingKey(
                        desktop: entry.desktop,
                        arrangement: entry.arrangement
                    )
                ] = entry.ratios
            }
            return out
        }

        private enum CodingKeys: String, CodingKey {
            case ratios = "session_ratios"
            case desktopRatios = "desktop_ratios"
            case stackWeights = "stack_weights"
            case runSizes = "run_sizes"
            case scrollRest = "scroll_rest"
            case monocleShown = "monocle_shown"
            case maximized
            case maximizeShape = "maximize_shape"
            case maximizeFollows = "maximize_follows"
            case runHeads = "run_heads"
            case runTails = "run_tails"
        }
    }

    /// A Space's sizes as the in-place capture reads them (#2921):
    /// every entry, and the set it draws now.
    public struct SessionSizing: Sendable {
        public var entries: [SessionSizingKey: SessionRatios]
        public var drawn: SessionRatios

        public init(
            entries: [SessionSizingKey: SessionRatios],
            drawn: SessionRatios
        ) {
            self.entries = entries
            self.drawn = drawn
        }
    }

    /// One Desktop's sizes for a Space under one arrangement
    /// (#2921); a nil `desktop` is the shared entry.
    public struct DesktopRatios: Codable, Sendable, Equatable {
        public var desktop: SkyLight.SpaceID?
        public var arrangement: HeldOrigin.Arrangement?
        public var ratios: SessionRatios

        public init(
            desktop: SkyLight.SpaceID?,
            arrangement: HeldOrigin.Arrangement?,
            ratios: SessionRatios
        ) {
            self.desktop = desktop
            self.arrangement = arrangement
            self.ratios = ratios
        }

        /// A stable order for the capture's list.
        var order: String {
            "\(desktop.map(String.init) ?? "")|"
                + (arrangement.map { String(describing: $0) } ?? "")
        }

        private enum CodingKeys: String, CodingKey {
            case desktop
            case arrangement
            case ratios = "session_ratios"
        }
    }

    /// One window's runtime flags: the sticky scope, the
    /// sticky-reach override and a Tile over a float rule. The hand
    /// float rides the record itself, on every stop (#1864,
    /// `StateSnapshot+StopFloats`).
    public struct WindowSession: Codable, Sendable, Equatable {
        public var sticky: StickyScope
        public var stickyReach: Bool?
        /// A Tile over a float rule (#2975), `true` else nil: a
        /// crash or a quit floats the window again.
        public var tiledOverRule: Bool?

        public init(
            sticky: StickyScope,
            stickyReach: Bool?,
            tiledOverRule: Bool? = nil
        ) {
            self.sticky = sticky
            self.stickyReach = stickyReach
            self.tiledOverRule = tiledOverRule
        }

        private enum CodingKeys: String, CodingKey {
            case sticky
            case stickyReach = "sticky_reach"
            case tiledOverRule = "tiled_over_rule"
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
        ratios: (SpaceID) -> StateSnapshot.SessionSizing
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
                    stickyReach: stickyReachOverrides[window.id],
                    tiledOverRule: tilesOverRule(window.id) ? true : nil
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
            $0.runSizes = Dictionary(
                uniqueKeysWithValues: (session.runSizes ?? [:]).map {
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
                $0.maximized = Maximize(
                    window: WindowID(raw),
                    shape: session.maximizeShape ?? .full,
                    follows: session.maximizeFollows ?? false
                )
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
