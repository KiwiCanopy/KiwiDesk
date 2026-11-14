import Foundation
import os

/// The fingers on the trackpad now, as the touch reader last saw
/// them (#1873): written on the reader's thread at every frame and
/// read by the pointer tap's callback at a Dock stream's begin,
/// where the event carries no finger count. A lock read, never a
/// wait on the main actor; 0 while no reader runs.
enum TouchFingerCount {
    private static let count = OSAllocatedUnfairLock(initialState: 0)

    static var now: Int { count.withLock { $0 } }

    static func set(_ fingers: Int) {
        count.withLock { $0 = fingers }
    }
}
