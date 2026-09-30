import Foundation

/// A temporary Space's record in the session snapshot (#1790): on
/// its own Space record, in every capture, so a quit, a crash and
/// an in-place restart all bring it back. A stored cross-version
/// shape.
extension StateSnapshot {
    public struct TemporaryRecord: Codable, Sendable, Equatable {
        /// `TemporarySpace.armed`.
        public var armed: Bool
        /// The screen it is pinned to — a New Space's — which no
        /// arrangement records.
        public var pin: String?

        public init(armed: Bool, pin: String? = nil) {
            self.armed = armed
            self.pin = pin
        }
    }
}

extension StateCoordinator {
    /// The record of live Space `id`, if it is temporary; its pin
    /// is `KiwiCore.sessionSnapshot`'s to add.
    func temporaryRecord(of id: SpaceID) -> StateSnapshot.TemporaryRecord? {
        temporarySpaces[id].map { .init(armed: $0.armed) }
    }
}
