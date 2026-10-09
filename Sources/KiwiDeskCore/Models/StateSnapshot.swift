import CoreGraphics
import Foundation

/// Serializable snapshot of full window management state (`SleepWakeManager`).
public struct StateSnapshot: Codable, Sendable, Equatable {
    public struct WindowRecord: Codable, Sendable, Equatable {
        public let id: UInt32
        public let frame: CGRect
        /// In-place restarts only (#930, `StateSnapshot+InPlace`).
        public var session: WindowSession?
        /// The bundle id and title a snapshot from another boot or
        /// login is matched on, its ids naming nothing there
        /// (#1385, `CrossSessionMatch`).
        public var app: String?
        public var title: String?

        public init(
            id: WindowID,
            frame: CGRect,
            session: WindowSession? = nil,
            app: String? = nil,
            title: String? = nil
        ) {
            self.id = id.raw
            self.frame = frame
            self.session = session
            self.app = app
            self.title = title
        }

        private enum CodingKeys: String, CodingKey {
            case id, frame, session, app, title
        }

        /// The in-place payload decodes on its own: one this build
        /// cannot read (another build's shape) costs only itself,
        /// never the record or the file (#930).
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UInt32.self, forKey: .id)
            frame = try c.decode(CGRect.self, forKey: .frame)
            session = try? c.decodeIfPresent(
                WindowSession.self,
                forKey: .session
            )
            app = try? c.decodeIfPresent(String.self, forKey: .app)
            title = try? c.decodeIfPresent(String.self, forKey: .title)
        }

        public var windowID: WindowID { WindowID(id) }
    }

    public struct SpaceRecord: Codable, Sendable, Equatable {
        public private(set) var id: String
        public let mode: LayoutMode
        public let windows: [UInt32]
        public let focused: UInt32?
        /// Track breaks and weights preserved across restore
        /// (#128). The per-window `stackWeights` ride only the
        /// in-place `session` (#930): an even re-split degrades
        /// gracefully, while a lost partition restructures the
        /// space.
        public let trackBreaks: [UInt32]
        public let trackWeights: [UInt32: Double]
        /// In-place restarts only (#930, `StateSnapshot+InPlace`).
        public var session: SpaceSession?
        /// The Space's hold, in every snapshot (#1646,
        /// `StateSnapshot+Held`).
        public var held: HeldRecord?
        /// Whether the Space is temporary, in every snapshot
        /// (#1790, `KiwiCore+TemporarySpaceBoot`).
        public var temporary: TemporaryRecord?
        /// Windows filed here that have not arrived — a late
        /// window's restore filing, a Desktop departure (#2008).
        /// A held Space carries them on `held` instead.
        public var pending: [UInt32]

        public init(
            space: Space,
            session: SpaceSession? = nil,
            held: HeldRecord? = nil,
            temporary: TemporaryRecord? = nil,
            pending: [WindowID] = []
        ) {
            self.session = session
            self.held = held
            self.temporary = temporary
            self.pending = pending.map(\.raw)
            self.id = space.id.raw
            self.mode = space.mode
            self.windows = space.windows.map(\.raw)
            self.focused = space.focused?.raw
            self.trackBreaks = space.trackBreaks.map(\.raw)
            self.trackWeights = Dictionary(
                uniqueKeysWithValues: space.trackWeights.map {
                    ($0.key.raw, $0.value)
                }
            )
        }

        private enum CodingKeys: String, CodingKey {
            case id, mode, windows, focused, session, held, temporary
            case pending
            case trackBreaks = "track_breaks"
            case trackWeights = "track_weights"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(
                keyedBy: CodingKeys.self
            )
            id = try c.decode(String.self, forKey: .id)
            mode = try c.decode(LayoutMode.self, forKey: .mode)
            windows = try c.decode(
                [UInt32].self,
                forKey: .windows
            )
            focused = try c.decodeIfPresent(
                UInt32.self,
                forKey: .focused
            )
            trackBreaks =
                try c.decodeIfPresent(
                    [UInt32].self,
                    forKey: .trackBreaks
                ) ?? []
            trackWeights =
                try c.decodeIfPresent(
                    [UInt32: Double].self,
                    forKey: .trackWeights
                ) ?? [:]
            // On its own, as `WindowRecord`'s (#930).
            session = try? c.decodeIfPresent(
                SpaceSession.self,
                forKey: .session
            )
            // On its own too: an unreadable hold costs itself.
            held = try? c.decodeIfPresent(HeldRecord.self, forKey: .held)
            temporary = try? c.decodeIfPresent(
                TemporaryRecord.self,
                forKey: .temporary
            )
            pending =
                (try? c.decodeIfPresent([UInt32].self, forKey: .pending))
                ?? []
        }

        /// This record under another id (#1646's boot renumber).
        func renamed(to id: String) -> SpaceRecord {
            var copy = self
            copy.id = id
            return copy
        }
    }

    public var windows: [WindowRecord]
    public var spaces: [SpaceRecord]
    public var activeSpace: String?
    public var capturedAt: Date
    /// The arrangement live at the capture (#1646): a replay under
    /// another one leaves the modes of the Spaces it declares.
    public var arrangement: HeldOrigin.Arrangement?
    /// Every arrangement's #1230 record (#1802, #1829,
    /// `StateSnapshot+ProfileRecords`).
    public var arrangementRecords: ArrangementRecords?
    /// The login session the file was written in, stamped by
    /// `CrashRecovery`'s write (#1385); nil in an older build's.
    public var loginSession: Int32?
    /// Written by a logout's freeze (#1385): the one file a later
    /// boot may match by stable key, once.
    public var frozenForLogout = false

    public init(
        windows: [WindowRecord],
        spaces: [SpaceRecord],
        activeSpace: String?,
        capturedAt: Date = .now,
        arrangement: HeldOrigin.Arrangement? = nil
    ) {
        self.windows = windows
        self.spaces = spaces
        self.activeSpace = activeSpace
        self.capturedAt = capturedAt
        self.arrangement = arrangement
    }

    private enum CodingKeys: String, CodingKey {
        case windows, spaces, activeSpace, capturedAt, arrangement
        case arrangementRecords, loginSession, frozenForLogout
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windows = try c.decode([WindowRecord].self, forKey: .windows)
        spaces = try c.decode([SpaceRecord].self, forKey: .spaces)
        activeSpace = try c.decodeIfPresent(
            String.self,
            forKey: .activeSpace
        )
        capturedAt = try c.decode(Date.self, forKey: .capturedAt)
        // On its own: an unreadable one replays as an older file.
        arrangement = try? c.decodeIfPresent(
            HeldOrigin.Arrangement.self,
            forKey: .arrangement
        )
        // On its own too: an unreadable one replays as no record.
        arrangementRecords = try? c.decodeIfPresent(
            ArrangementRecords.self,
            forKey: .arrangementRecords
        )
        // Unreadable reads as unstamped, which the gate refuses.
        loginSession = try? c.decodeIfPresent(
            Int32.self,
            forKey: .loginSession
        )
        frozenForLogout =
            (try? c.decodeIfPresent(Bool.self, forKey: .frozenForLogout))
            ?? false
    }
}

extension StateCoordinator {
    /// Re-applies snapshot state. A snapshot space that no longer
    /// exists is skipped, never created (#633): the loaded
    /// config/profile is the space-set authority, and an
    /// `ensureSpace` here resurrected pruned spaces which the next
    /// save persisted — corrupting `gui.json` from a restore
    /// (#128). A held Space exists here because boot's
    /// `restoreHeldSpaces` created it ahead of the replay (#1646).
    public mutating func adopt(_ snapshot: StateSnapshot) {
        for record in snapshot.spaces {
            let space = SpaceID(record.id)
            guard workspaces[space] != nil else { continue }
            for raw in record.windows {
                let id = WindowID(raw)
                if windows[id] != nil {
                    workspaces.add(id, to: space)
                } else {
                    remember(id, in: space)
                }
            }
            if let raw = record.focused,
                windows[WindowID(raw)] != nil
            {
                workspaces.focus(WindowID(raw), in: space)
            }
            // Trigger on "the record IS a track space", not on
            // marker non-emptiness: an all-merged track space
            // captures empty/empty, and `restore` re-applies the
            // mode first (#633) — the empty write clears the
            // mode-entry seed back to the captured single track.
            if record.mode == .track
                || !record.trackBreaks.isEmpty
                || !record.trackWeights.isEmpty
            {
                workspaces.withSpace(space) {
                    $0.trackBreaks = Set(
                        record.trackBreaks.map(WindowID.init)
                    )
                    $0.trackWeights = Dictionary(
                        uniqueKeysWithValues:
                            record.trackWeights.map {
                                (WindowID($0.key), $0.value)
                            }
                    )
                }
            }
            refilePending(record.pending.map(WindowID.init), in: space)
            adoptSession(record, in: space)
        }
        for record in snapshot.windows {
            adoptSession(of: record)
        }
        if let active = snapshot.activeSpace,
            workspaces[SpaceID(active)] != nil
        {
            workspaces.activate(SpaceID(active))
        }
    }

    /// Captures the current state for later restoration.
    public func snapshot() -> StateSnapshot {
        StateSnapshot(
            windows: windows.all.map {
                StateSnapshot.WindowRecord(
                    id: $0.id,
                    frame: $0.frame,
                    app: $0.appBundleID,
                    title: $0.title
                )
            } + owedFrameRecords(),
            spaces: workspaces.allSpaces.map { spaceRecord(of: $0) },
            activeSpace: workspaces.activeSpace?.raw
        )
    }
}
