import CoreGraphics
import Foundation

/// The hand floats a STOP carries (#1864): the quit gather arranges
/// every float, so the next launch owes each its flag back, and an
/// in-place stop carries them on the same field. An autosave and a
/// wake's capture mark none, so a crash still starts them fresh
/// (#930 ruling 5); a debt owed to a window not yet arrived rides
/// every capture, as its frame does (#2008). A detection float
/// takes no mark: the scan re-derives it (#1810).
extension StateCoordinator {
    /// What a restored window is owed at its arrival (#1362).
    struct RestoredArrival: Equatable, Sendable {
        /// The snapshot frame, as recorded; a corner is delivered
        /// nowhere (#1352), but rides along so a later capture
        /// keeps the debt.
        var frame: CGRect
        /// A hand float the stop carried.
        var floating = false
    }

    /// `snapshot` with every tracked hand float's record marked —
    /// the stop's capture.
    func markingStopFloats(_ snapshot: StateSnapshot) -> StateSnapshot {
        snapshot.mappingWindowRecords { record in
            guard userFloated.contains(record.windowID) else {
                return record
            }
            var marked = record
            marked.floating = true
            return marked
        }
    }

    /// Re-floats a tracked window a stop marked; an untracked one
    /// is owed it through `restoredFrames` by the replay.
    mutating func adoptStopFloat(of record: StateSnapshot.WindowRecord) {
        guard record.floating == true, windows[record.windowID] != nil
        else { return }
        floatByHand(record.windowID)
    }

    /// Only where detection tiles the window (#1810): a window
    /// detection floats takes no user record. True when it floated.
    @discardableResult
    mutating func floatByHand(_ id: WindowID) -> Bool {
        guard windows[id]?.isFloating == false else { return false }
        setFloating(id, true)
        return true
    }
}
