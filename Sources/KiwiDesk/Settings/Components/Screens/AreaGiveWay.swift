import Foundation
import KiwiDeskCore

/// Which area gives way to a typed size in Adjust… (#3517 ruling
/// 26): among every area but the field in focus, the last one not
/// yet typed in this popover, reading from the end; once all are
/// typed, the one typed longest ago. With two areas, the other one.
enum AreaGiveWay {
    /// `order` is the areas in reading order, `typed` the ones
    /// typed this session, oldest first.
    static func pick(
        order: [Int],
        typed: [Int],
        excluding focused: Int?
    ) -> Int? {
        let candidates = order.filter { $0 != focused }
        if let untyped = candidates.last(where: { !typed.contains($0) }) {
            return untyped
        }
        return typed.first { candidates.contains($0) }
    }

    /// `typed` with `id` moved to the newest end.
    static func typing(_ id: Int, after typed: [Int]) -> [Int] {
        typed.filter { $0 != id } + [id]
    }
}

/// One presentation of Adjust… (#843): a fresh id per open, and the
/// sizes it opened on, which Escape writes back.
struct AreaSizesRequest: Identifiable, Equatable {
    let id = UUID()
    let display: DisplayID
    let seed: ScreenSplit
}

/// One presentation of an area's Rename… (#843).
struct AreaRenameRequest: Identifiable, Equatable {
    let id = UUID()
    let display: DisplayID
    let area: Int
}
