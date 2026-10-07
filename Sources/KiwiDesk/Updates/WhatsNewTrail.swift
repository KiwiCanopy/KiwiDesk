import KiwiDeskCore
import SwiftUI

/// The way back from Settings to What's new after a spotlight
/// row's "Show me" (#2038 ruling ▸ handoff): the rows this build
/// can land on, in digest order, the one landed on, and What's
/// new's two answers. A value, so the banner's rules are pinned
/// without a window (`WhatsNewTrailTests`).
struct WhatsNewTrail {
    struct Stop: Equatable {
        let title: String
        let anchor: SettingsAnchor
    }

    /// Every linked row, in digest order; never empty.
    let stops: [Stop]
    private(set) var index: Int
    /// Re-presents the retained What's new window.
    let back: @MainActor () -> Void
    /// Finishes What's new — its Done.
    let dismiss: @MainActor () -> Void

    var current: Stop { stops[index] }

    /// The next linked row; nil on the last, where Next is
    /// absent rather than greyed.
    var next: Stop? {
        stops.indices.contains(index + 1) ? stops[index + 1] : nil
    }

    /// The trail one stop on; nil on the last.
    func advanced() -> WhatsNewTrail? {
        guard next != nil else { return nil }
        var trail = self
        trail.index += 1
        return trail
    }

    /// Nil where `picked` has no landing in this build — a row
    /// whose link is dropped, which offers no "Show me" either.
    init?(
        spotlight: [UpdateNotesDigest.SpotlightEntry],
        picked: UpdateNotesDigest.SpotlightEntry,
        landing: (String?) -> SettingsAnchor?,
        back: @escaping @MainActor () -> Void,
        dismiss: @escaping @MainActor () -> Void
    ) {
        var stops: [Stop] = []
        var index: Int?
        for entry in spotlight {
            guard let anchor = landing(entry.row.setting) else {
                continue
            }
            if index == nil, entry == picked { index = stops.count }
            stops.append(Stop(title: entry.row.title, anchor: anchor))
        }
        guard let index else { return nil }
        self.stops = stops
        self.index = index
        self.back = back
        self.dismiss = dismiss
    }
}

/// Where a spotlight row's census id lands (#2038): the search
/// row that id indexes, so "Show me" lands as the search would —
/// page, surface, the control flashed. Nil where this build does
/// not know the id or does not index it: the link is dropped.
@MainActor
enum SpotlightLanding {
    static func anchor(for id: String?) -> SettingsAnchor? {
        guard let id else { return nil }
        return SettingsSearchIndex.rows().first { $0.key?.id == id }?
            .anchor
    }
}

/// A spotlight row's "Show me" (#2038): the ONE seam the row
/// calls; what it does with the window is the caller's.
typealias SpotlightShowMe =
    @MainActor (UpdateNotesDigest.SpotlightEntry) -> Void

private struct SpotlightShowMeKey: EnvironmentKey {
    static let defaultValue: SpotlightShowMe? = nil
}

extension EnvironmentValues {
    /// Set only where the window can hand off to Settings — What's
    /// new — so the offer and the up-to-date answer draw no link.
    var spotlightShowMe: SpotlightShowMe? {
        get { self[SpotlightShowMeKey.self] }
        set { self[SpotlightShowMeKey.self] = newValue }
    }
}
