import Foundation

/// `open_in_background`'s holds (#3141), a slot of the launch
/// follow's ledger: per app, when it was opened behind the focus,
/// owed ONE hand-back of the focus it takes within `grace`. Stamped
/// per app, so a run of opens grants each its own grace; lifted by
/// the user naming the app (`LaunchFollowIntent.record`), and never
/// by an activation, since the user working on is the case it is for.
struct BackgroundHolds {
    /// An Electron app activated itself 1.4–1.5 s after `open -g`
    /// on the owner's Mac; the bound leaves a slow cold start room
    /// while keeping the accepted trade, a keyboard switch to the
    /// app inside it handed back once, short.
    static let grace: TimeInterval = 10

    private(set) var opened: [String: Date] = [:]

    /// Owes `app` a hand-back from `now`, replacing its own stamp.
    mutating func note(_ app: String, at now: Date) {
        opened[app] = now
    }

    /// Takes `app`'s hand-back, once, within the grace.
    mutating func claim(_ app: String, at now: Date) -> Bool {
        guard let at = opened.removeValue(forKey: app) else {
            return false
        }
        return now.timeIntervalSince(at) < Self.grace
    }

    /// Drops `app`'s hand-back unpaid.
    mutating func lift(_ app: String) {
        opened[app] = nil
    }
}
