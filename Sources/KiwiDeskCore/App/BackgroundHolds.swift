import Foundation

/// `open_in_background`'s holds (#3141), a slot of the launch
/// follow's ledger: per app, when it was opened behind the focus,
/// owed ONE hand-back of the focus it takes within `grace`, and when
/// an activation of it was handed back, whose own reports echo it;
/// and the Space its windows are filed into where one was named
/// (#3152), read while its quiet mark stands. Stamped per app, so a
/// run of opens grants each its own grace; lifted by
/// the user naming the app (`LaunchFollowIntent.record`), and never
/// by an activation, since the user working on is the case it is for.
struct BackgroundHolds {
    /// An Electron app activated itself 1.4–1.5 s after `open -g`
    /// on the owner's Mac; the bound leaves a slow cold start room
    /// while keeping the accepted trade, a keyboard switch to the
    /// app inside it handed back once, short.
    static let grace: TimeInterval = 10

    /// How long after an activation's hand-back the app's own
    /// focus reports are that activation's: its focused-window read
    /// is asked after the hand-back and took 1.09 s off main for
    /// VS Code on the owner's Mac (2026-11-09 log).
    static let echoGrace: TimeInterval = 2

    /// Read by tests; written through the methods below alone.
    private(set) var opened: [String: Date] = [:]
    /// When each app's activation was handed back; never renewed.
    private(set) var handedBack: [String: Date] = [:]
    /// The Space each app's windows are filed into (#3152).
    private(set) var spaces: [String: SpaceID] = [:]

    /// Owes `app` a hand-back from `now`, replacing its own stamp,
    /// its windows filed into `space` where one is named.
    mutating func note(_ app: String, at now: Date, into space: SpaceID?) {
        opened[app] = now
        spaces[app] = space
    }

    /// Ends `app`'s filing: the user took the app, so its next
    /// window lands where they are.
    mutating func liftSpace(_ app: String) {
        spaces[app] = nil
    }

    /// Takes `app`'s hand-back, once, within the grace.
    mutating func claim(_ app: String, at now: Date) -> Bool {
        guard let at = opened.removeValue(forKey: app) else {
            return false
        }
        return now.timeIntervalSince(at) < Self.grace
    }

    /// Notes that `app`'s activation was handed back at `now`.
    mutating func markHandedBack(_ app: String, at now: Date) {
        handedBack[app] = now
    }

    /// Whether a report of `app` at `now` still belongs to the
    /// activation handed back, within `echoGrace`.
    func echoes(_ app: String, at now: Date) -> Bool {
        handedBack[app].map { now.timeIntervalSince($0) < Self.echoGrace }
            ?? false
    }

    /// Notes `app` coming forward: with no hold left it is a take
    /// of its own, which ends the echo of the last hand-back.
    mutating func noteActivation(_ app: String) {
        if opened[app] == nil { handedBack[app] = nil }
    }

    /// Drops `app`'s hand-back unpaid, its echo and its filing.
    mutating func lift(_ app: String) {
        opened[app] = nil
        handedBack[app] = nil
        spaces[app] = nil
    }
}
