import Foundation

/// The apps the automatic-float guess has floated a window of since
/// launch (#2071), most recently seen first — the Tile picker's
/// list. Recorded whatever the switch and the Tile rules say, kept
/// in memory only, and bounded at `cap`, the least recently seen
/// app dropped first.
struct GuessedApps: Equatable {
    struct Entry: Equatable {
        /// Lowercased, as a Tile rule matches it.
        let bundleID: String
        /// The app's name when last seen; it may have quit since.
        let name: String
    }

    static let cap = 20

    private(set) var entries: [Entry] = []

    /// Moves `bundleID` to the front, evicting past `cap`.
    mutating func note(bundleID: String, name: String) {
        let key = bundleID.lowercased()
        entries.removeAll { $0.bundleID == key }
        entries.insert(Entry(bundleID: key, name: name), at: 0)
        if entries.count > Self.cap {
            entries.removeLast(entries.count - Self.cap)
        }
    }
}
