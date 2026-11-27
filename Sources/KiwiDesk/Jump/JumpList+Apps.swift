import Foundation
import KiwiDeskCore

/// An app the Applications section may list (#3704): installed or
/// running, with no row in the list.
struct JumpAppCandidate: Equatable {
    /// Lowercased, as Core's app verbs take it.
    let bundleID: String
    let name: String
    /// Running with no window: "Open, no windows"; else "Not open".
    let running: Bool

    /// The installed apps and Core's running ones, less every app a
    /// row or the current window already holds and KiwiDesk itself.
    static func build(
        installed: [InstalledApps.App],
        running: [JumpRunningApp],
        own: String?
    ) -> [JumpAppCandidate] {
        let own = own?.lowercased()
        let listed = Set(running.filter(\.listed).map(\.bundleID))
        var byID: [String: JumpAppCandidate] = [:]
        for app in installed {
            byID[app.bundleID] = JumpAppCandidate(
                bundleID: app.bundleID,
                name: app.name,
                running: false
            )
        }
        for app in running where !app.listed {
            byID[app.bundleID] = JumpAppCandidate(
                bundleID: app.bundleID,
                name: byID[app.bundleID]?.name ?? app.name,
                running: true
            )
        }
        return byID.values.filter {
            !listed.contains($0.bundleID) && $0.bundleID != own
        }
    }
}

/// One Applications row: the app and where its name matched.
struct JumpAppMatch: Equatable {
    let app: JumpAppCandidate
    let range: Range<String.Index>
}

extension JumpList {
    /// The most Applications rows a query lists (#3704).
    static let appCap = 5

    /// Every row the keys reach: the windows', then the apps'.
    var rowCount: Int { results.count + appResults.count }

    /// Where the Applications section starts, nil without one.
    var appsStart: Int? { appResults.isEmpty ? nil : results.count }

    /// The app row at list index `index`, nil on a window row.
    func appRow(_ index: Int) -> JumpAppMatch? {
        let at = index - results.count
        return appResults.indices.contains(at) ? appResults[at] : nil
    }

    /// The selected app row; nil on a window row.
    var selectedApp: JumpAppMatch? { selection.flatMap(appRow) }

    /// `candidates` matching `query` by name through Core's one
    /// matcher, by match quality, running first on a tie, then by
    /// name, at most `appCap`; none for a blank query.
    static func appMatches(
        _ candidates: [JumpAppCandidate],
        query: String
    ) -> [JumpAppMatch] {
        let ranked = candidates.compactMap {
            app -> (tier: Int, match: JumpAppMatch)? in
            guard let (tier, range) = JumpSearch.nameMatch(query, in: app.name)
            else { return nil }
            return (tier, JumpAppMatch(app: app, range: range))
        }
        return ranked.sorted { lhs, rhs in
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            let left = lhs.match.app
            let right = rhs.match.app
            if left.running != right.running { return left.running }
            let order = left.name.localizedStandardCompare(right.name)
            return order != .orderedSame
                ? order == .orderedAscending : left.bundleID < right.bundleID
        }.prefix(appCap).map(\.match)
    }
}
