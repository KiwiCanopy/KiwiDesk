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
