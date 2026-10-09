import CoreGraphics
import Foundation

/// Matches a snapshot from another boot or login to the windows
/// macOS reopens, whose ids are new (#1385 ruling 2026-10-09): by
/// app first, by title once titles settle, then by rank. Pure and
/// clockless: the caller's scheduled passes `settle()` and
/// `close()` it, so a wall-clock step cannot move either (#1385).
struct CrossSessionMatch: Sendable, Equatable {
    /// Boot-time titles are generic or empty; measured renames
    /// landed inside 30 s of boot.
    static let titleSettle: TimeInterval = 30
    /// How long a reopened window may still arrive; measured: Zen
    /// at +30 s.
    static let bound: TimeInterval = 120

    /// One snapshot window still waiting for its reopened twin.
    struct Record: Sendable, Equatable {
        /// The id in the snapshot; names nothing in this session.
        let id: WindowID
        let space: SpaceID
        let app: String
        let title: String
        let frame: CGRect
    }

    /// A tracked or arriving window the match may take.
    struct Candidate: Sendable, Equatable {
        let id: WindowID
        let app: String
        let title: String
    }

    /// Set by the title pass; titles pair only after it.
    private(set) var settled = false
    /// Waiting records, in the snapshot's Space-then-row order —
    /// each app's in its rank order.
    private(set) var pending: [Record] = []
    /// Live windows placed, or filed by a user verb since the
    /// match armed — never taken, so no pass undoes a user move.
    var placed: Set<WindowID> = []

    init() {}

    /// The records of `snapshot` that carry a bundle id and sit in
    /// a Space `exists` admits; empty when none do.
    init(
        _ snapshot: StateSnapshot,
        exists: (SpaceID) -> Bool
    ) {
        let byID = Dictionary(
            snapshot.windows.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for space in snapshot.spaces where exists(SpaceID(space.id)) {
            for raw in space.windows {
                guard let record = byID[raw], let app = record.app
                else { continue }
                pending.append(
                    Record(
                        id: WindowID(raw),
                        space: SpaceID(space.id),
                        app: app,
                        title: record.title ?? "",
                        frame: record.frame
                    )
                )
            }
        }
    }

    /// Open while a record waits; `close()` ends it.
    var isOpen: Bool { !pending.isEmpty }

    /// Titles have settled; the title pass calls it.
    mutating func settle() { settled = true }

    /// The pairs `live` earns now. Before the settle only an app
    /// with one record and one live window pairs; after it, an
    /// equal title takes the lowest-ranked record, then the rest
    /// pair by rank — live windows in id order, so identical
    /// titles land in their app's Spaces, order unknown.
    func pairs(
        _ live: [Candidate]
    ) -> [(window: WindowID, record: Record)] {
        guard isOpen else { return [] }
        let byApp = Dictionary(grouping: live) { $0.app }
        var out: [(window: WindowID, record: Record)] = []
        for app in byApp.keys.sorted() {
            let windows = (byApp[app] ?? [])
                .filter { !placed.contains($0.id) }
                .sorted { $0.id.raw < $1.id.raw }
            var records = pending.filter { $0.app == app }
            guard !records.isEmpty, !windows.isEmpty else { continue }
            guard settled else {
                if records.count == 1, windows.count == 1 {
                    out.append((windows[0].id, records[0]))
                }
                continue
            }
            var rest: [Candidate] = []
            for window in windows {
                if let index = records.firstIndex(where: {
                    $0.title == window.title
                }) {
                    out.append((window.id, records.remove(at: index)))
                } else {
                    rest.append(window)
                }
            }
            for (window, record) in zip(rest, records) {
                out.append((window.id, record))
            }
        }
        return out
    }

    /// Takes `pairs` out of the match.
    mutating func commit(
        _ pairs: [(window: WindowID, record: Record)]
    ) {
        let taken = Set(pairs.map(\.record.id))
        pending.removeAll { taken.contains($0.id) }
        placed.formUnion(pairs.map(\.window))
    }

    /// Ends the match; returns how many records never paired.
    mutating func close() -> Int {
        let missed = pending.count
        self = CrossSessionMatch()
        return missed
    }
}
