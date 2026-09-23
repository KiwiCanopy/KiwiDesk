import Foundation

/// Why a Desktop binding loads no profile, and the ONE judgement
/// of whether a profile's screen count fits the connected one
/// (#1394): Core decides it, the Desktops rows only narrate it
/// (`DesktopBindingFitSeamTests`).
public enum DesktopBindingRefusal: Error {
    /// No bound profile's file could be read.
    case unreadable(Error)
    /// No bound profile is saved for the connected count;
    /// `saved` is each READABLE one with its count, in binding
    /// order (#1436) — an unreadable sibling is not among them.
    case screenCount(saved: [SavedCount], connected: Int)

    /// One readable bound profile and the count it is saved for.
    public struct SavedCount: Equatable, Sendable {
        public let name: String
        public let count: Int
    }
    /// No display reading yet: the first config load runs before
    /// the loop publishes displays, and a paused engine discovers
    /// none. The first monitor change re-judges.
    case displaysUnknown
    /// Every bound profile is scoped to another screen setup than
    /// the connected one (#1609).
    case otherSetups

    /// The count verdict alone, pure; nil where `profileCount`
    /// fits `connected`. A `.screenCount` from here carries no
    /// census — `saved` is empty, since one count names no
    /// profile; the gate fills it over the binding.
    public static func of(
        profileCount: Int,
        connected: Int
    ) -> DesktopBindingRefusal? {
        if connected == 0 { return .displaysUnknown }
        guard profileCount == connected else {
            return .screenCount(saved: [], connected: connected)
        }
        return nil
    }

    /// The log line's tail, after the door names itself.
    func narrative(binding: DesktopBinding) -> String {
        let names = binding.profiles.map { "'\($0)'" }
            .joined(separator: ", ")
        let plural = binding.profiles.count > 1
        switch self {
        case .unreadable(let error):
            return "cannot load profile\(plural ? "s" : "") "
                + "\(names): \(error)"
        case .screenCount(let saved, let connected):
            let counted =
                saved.count == 1
                ? "profile '\(saved[0].name)' is for \(saved[0].count)"
                : "profiles "
                    + saved.map { "'\($0.name)' for \($0.count)" }
                    .joined(separator: ", ")
            return
                "\(counted) screen(s), \(connected) connected; "
                + "the binding stands aside"
        case .displaysUnknown:
            return
                "profile\(plural ? "s" : "") \(names) "
                + "wait\(plural ? "" : "s") for the first display "
                + "reading; the binding stands aside"
        case .otherSetups:
            return
                "profile\(plural ? "s" : "") \(names) "
                + "\(plural ? "are" : "is") bound for other screen "
                + "setups; the binding stands aside"
        }
    }
}

/// What a Desktop binding loads: the profile, and the entry that
/// fired it (#1609) — so a reader of the rung asks the pick rather
/// than re-deriving which tier matched.
struct BoundPick {
    let profile: Profile
    let entry: DesktopBinding.Entry
}

/// A binding whose list is empty — a shape no writer produces,
/// named so the gate can refuse it rather than crash.
struct EmptyDesktopBinding: Error {}

extension KiwiCore {
    /// The profile a Desktop binding loads, or why it does not —
    /// the ONE gate every reader of a binding's profile takes
    /// (#1394, `DesktopBindingFitTests`).
    ///
    /// A binding fires only through a bound profile saved for
    /// the connected screen count (#1436) and scoped to the
    /// connected setup or to all of them (#1609): one scoped to
    /// exactly these screens first, then one for all setups —
    /// within each, the LIVE one where it is listed and fits,
    /// else the first in binding order that does — the one rank
    /// `DesktopBinding.ranked(for:preferring:)` gives, so the
    /// door's stand-down for the live profile is this gate's own
    /// pick. With none, and before the first display reading, it
    /// stands aside and the rungs below it answer. A bound load
    /// therefore always fits by count and by scope.
    func boundProfile(
        of binding: DesktopBinding
    ) -> Result<BoundPick, DesktopBindingRefusal> {
        let connected = state.workspaces.allDisplays.count
        let ranked = binding.ranked(
            for: liveFingerprints,
            preferring: profiles.currentName
        )
        if ranked.isEmpty, !binding.entries.isEmpty {
            return .failure(
                connected == 0 ? .displaysUnknown : .otherSetups
            )
        }
        var saved: [DesktopBindingRefusal.SavedCount] = []
        var unreadable: Error = EmptyDesktopBinding()
        var waiting = false
        for entry in ranked {
            let name = entry.profile
            let profile: Profile
            do {
                profile = try profiles.read(name: name)
            } catch {
                unreadable = error
                continue
            }
            switch DesktopBindingRefusal.of(
                profileCount: profile.monitorCount,
                connected: connected
            ) {
            case nil:
                return .success(BoundPick(profile: profile, entry: entry))
            case .displaysUnknown?:
                waiting = true
            case .screenCount?:
                saved.append(
                    .init(name: name, count: profile.monitorCount)
                )
            case .unreadable?, .otherSetups?:
                break
            }
        }
        if waiting { return .failure(.displaysUnknown) }
        guard saved.isEmpty else {
            return .failure(
                .screenCount(saved: saved, connected: connected)
            )
        }
        return .failure(.unreadable(unreadable))
    }

    /// Whether the gate would pick the profile ALREADY live —
    /// answered from adoption state, never by reading its file
    /// (#1245, `DesktopBindingPerCountTests` ▸
    /// `liveProfileIsNotReread`): the live profile heads the
    /// gate's own rank for the connected setup (#1609) and fits
    /// the connected count. The binding door's stand-down; false
    /// sends it to `boundProfile(of:)`.
    func bindingPicksLiveProfile(_ binding: DesktopBinding) -> Bool {
        guard let live = profiles.currentName,
            let count = profiles.currentMonitorCount,
            binding.ranked(
                for: liveFingerprints,
                preferring: live
            ).first?.profile == live
        else { return false }
        return DesktopBindingRefusal.of(
            profileCount: count,
            connected: state.workspaces.allDisplays.count
        ) == nil
    }
}
