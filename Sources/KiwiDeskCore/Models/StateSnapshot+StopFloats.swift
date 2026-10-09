import Foundation

/// The hand floats a STOP carries (#1864): the quit gather arranges
/// every float, so the next launch owes each its flag back — and an
/// in-place stop carries them the same way. An autosave and a wake's
/// capture carry none, so a crash still starts them fresh (#930
/// ruling 5). A detection float takes no mark: the scan re-derives
/// it (#1810).
extension StateCoordinator {
    /// `snapshot` with every hand float's record marked, the ones
    /// owed at a late arrival included — the stop's capture.
    func markingStopFloats(_ snapshot: StateSnapshot) -> StateSnapshot {
        snapshot.mappingWindowRecords { record in
            let id = record.windowID
            guard userFloated.contains(id) || restoredFloats.contains(id)
            else { return record }
            var marked = record
            marked.floating = true
            return marked
        }
    }

    /// Re-applies a stop's hand float: a tracked window floats now,
    /// an untracked one filed by the replay at its arrival.
    mutating func adoptStopFloat(of record: StateSnapshot.WindowRecord) {
        guard record.floating == true else { return }
        let id = record.windowID
        guard windows[id] != nil else {
            if rememberedSpaces[id] != nil { restoredFloats.insert(id) }
            return
        }
        floatByHand(id)
    }

    /// Pays a hand float the replay owed this window, once, at its
    /// first arrival (#1362's lifetime).
    mutating func payRestoredFloat(of id: WindowID) {
        guard restoredFloats.remove(id) != nil else { return }
        floatByHand(id)
    }

    /// Only where detection tiles the window (#1810): a window
    /// detection floats takes no user record.
    private mutating func floatByHand(_ id: WindowID) {
        guard windows[id]?.isFloating == false else { return }
        setFloating(id, true)
    }
}
