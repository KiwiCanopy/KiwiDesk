import CoreGraphics
import Foundation

/// Serializable snapshot of full window management state (`SleepWakeManager`).
public struct StateSnapshot: Codable, Sendable, Equatable {
    public struct WindowRecord: Codable, Sendable, Equatable {
        public let id: UInt32
        public let frame: CGRect

        public init(id: WindowID, frame: CGRect) {
            self.id = id.raw
            self.frame = frame
        }

        public var windowID: WindowID { WindowID(id) }
    }

    public struct SpaceRecord: Codable, Sendable, Equatable {
        public let id: String
        public let mode: LayoutMode
        public let windows: [UInt32]
        public let focused: UInt32?
        /// Track breaks and weights preserved across restore
        /// (#128). The per-window `stackWeights` are deliberately
        /// NOT carried: an even re-split degrades gracefully,
        /// while a lost partition restructures the space.
        public let trackBreaks: [UInt32]
        public let trackWeights: [UInt32: Double]

        public init(space: Space) {
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
            case id, mode, windows, focused
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
        }
    }

    public var windows: [WindowRecord]
    public var spaces: [SpaceRecord]
    public var activeSpace: String?
    public var capturedAt: Date

    public init(
        windows: [WindowRecord],
        spaces: [SpaceRecord],
        activeSpace: String?,
        capturedAt: Date = .now
    ) {
        self.windows = windows
        self.spaces = spaces
        self.activeSpace = activeSpace
        self.capturedAt = capturedAt
    }
}

extension StateCoordinator {
    /// Re-applies snapshot state. A snapshot space that no longer
    /// exists is skipped, never created (#633): the loaded
    /// config/profile is the space-set authority, and an
    /// `ensureSpace` here resurrected pruned spaces which the next
    /// save persisted — corrupting `gui.json` from a restore
    /// (#128).
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
                    frame: $0.frame
                )
            },
            spaces: workspaces.allSpaces.map {
                StateSnapshot.SpaceRecord(space: $0)
            },
            activeSpace: workspaces.activeSpace?.raw
        )
    }
}
