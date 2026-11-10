import Foundation

extension LaunchFollowIntent {
    /// A quiet open's debt, owed through `oweLaunchFollow`: the apps
    /// opened in the background, stamped with the focus and the
    /// front app at the press, retired with the follow's debt. Its
    /// `purpose` says what it owes; one slot carries either.
    struct QuietOpen {
        /// What the debt owes.
        enum Purpose: Equatable {
            /// A lens's (#3122): ONE focus move, to the first of its
            /// apps' windows to arrive, within `quietBound`.
            case lens(String)
            /// `open_in_background`'s (#3141): ONE hand-back per app,
            /// of the focus it takes within `holdGrace`.
            case hold
        }

        let bundleIDs: Set<String>
        let purpose: Purpose
        let focus: WindowID?
        /// The front app at the press, whose own activation is no
        /// change of focus.
        let front: String?
        let at: Date

        /// Whether `bundleID`'s activation leaves the debt: one of
        /// its own apps, or the app that was in front. A hold stands
        /// any: the user working on is no reason to hand an app
        /// the focus.
        func survives(_ bundleID: String?) -> Bool {
            guard purpose != .hold else { return true }
            guard let app = bundleID?.lowercased() else { return false }
            return bundleIDs.contains(app) || app == front
        }

        /// This debt owing `apps` besides its own.
        func joining(_ apps: Set<String>) -> QuietOpen {
            owing(bundleIDs.union(apps))
        }

        /// This debt owing `apps` alone.
        func owing(_ apps: Set<String>) -> QuietOpen {
            QuietOpen(
                bundleIDs: apps,
                purpose: purpose,
                focus: focus,
                front: front,
                at: at
            )
        }
    }

    /// How long a background open's hold stands (#3141): an
    /// Electron app activated itself 1.4–1.5 s after `open -g` on
    /// the owner's Mac, so the bound leaves a slow cold start room
    /// while keeping the accepted trade, a clickless switch to the
    /// app inside it handed back once, short.
    static let holdGrace: TimeInterval = 10
}
