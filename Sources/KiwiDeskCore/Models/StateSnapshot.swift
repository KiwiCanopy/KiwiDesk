import CoreGraphics
import Foundation

/// Serializable snapshot of the full window management state.
///
/// Used by `SleepWakeManager` (restore after sleep/wake and
/// lock/unlock) and later by crash recovery. Codable so it can
/// be persisted to disk.
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

        public init(space: Space) {
            self.id = space.id.raw
            self.mode = space.mode
            self.windows = space.windows.map(\.raw)
            self.focused = space.focused?.raw
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
    /// Re-applies a snapshot's arrangement: window order per
    /// space, focus, and the active space. The array order IS
    /// the layout order, so without this a restart re-tiles
    /// windows in AX discovery order (seemingly shuffled).
    /// Snapshot windows that are not currently tracked (other
    /// native desktops, minimized) are remembered so they
    /// return to their space when they reappear.
    public mutating func adopt(_ snapshot: StateSnapshot) {
        for record in snapshot.spaces {
            let space = SpaceID(record.id)
            workspaces.ensureSpace(space)
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
        }
        if let active = snapshot.activeSpace {
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
