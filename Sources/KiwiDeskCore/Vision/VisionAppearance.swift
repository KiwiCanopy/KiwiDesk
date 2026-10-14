import Foundation

/// The system appearance KiwiVision asks for while it is on
/// (#2103 ruling 7). `unchanged` leaves the system alone;
/// `opposite` takes whichever the system is not showing.
public enum VisionAppearance: String, APIChoiceType, Sendable {
    case unchanged, opposite, dark, light

    /// The appearance asked for over `found`, nil for `unchanged`.
    func wantsDark(over found: SystemAppearance.State) -> Bool? {
        switch self {
        case .unchanged: return nil
        case .opposite: return !found.dark
        case .dark: return true
        case .light: return false
        }
    }
}

/// A switch KiwiVision made and still owes undoing: the state it
/// found, the one it last asked for, and when. Stored before the
/// switch, so a quit or crash leaves it for the next start. A
/// stored format in the app's defaults: a renamed field orphans a
/// live debt, so field names are frozen like a config key.
struct VisionAppearanceDebt: Codable, Equatable, Sendable {
    var found: SystemAppearance.State
    var setDark: Bool
    var askedAt: Date

    /// How long an ask may take to land before a read that
    /// disagrees counts as the user's own change — past the
    /// fallback's `osascript`, not past an Automation prompt left
    /// unanswered, which then reads as the user's.
    static let settleBound: TimeInterval = 10

    /// Whether `read` disagreeing with the ask is the user's doing.
    /// A debt asking for home never is: the only other value is
    /// the one KiwiVision itself switched to, so it stays owed until
    /// paid. Residue: a fallback ask still waiting on an Automation
    /// prompt past the bound reads as the user's.
    func overridden(by read: SystemAppearance.State, at now: Date) -> Bool {
        setDark != found.dark && read.dark != setDark
            && now.timeIntervalSince(askedAt) >= Self.settleBound
    }
}

/// The machine half of the appearance switch — the system
/// appearance and where the debt waits, which is this Mac's state
/// and so the app's defaults, never the config folder
/// (profiles.md). Live in production, inert in every test core, so
/// no suite flips the host's appearance (tests.md ▸ live host
/// state).
@MainActor
struct VisionAppearanceSwitch {
    var read: @MainActor () -> SystemAppearance.State
    /// Asks for `dark`; true when the switch was taken in the call.
    var setDark: @MainActor (Bool) -> Bool
    var rearmAuto: @MainActor () -> Void
    var readDebt: @MainActor () -> VisionAppearanceDebt?
    /// Stores the debt, or clears it on nil; false when it failed.
    var writeDebt: @MainActor (VisionAppearanceDebt?) -> Bool

    /// The defaults key the debt waits under.
    static let debtKey = "kiwivision.appearanceDebt"

    /// The system's own appearance and the app's defaults.
    static func live(
        onLog: @escaping @MainActor (String) -> Void
    ) -> VisionAppearanceSwitch {
        VisionAppearanceSwitch(
            read: { SystemAppearance.read() },
            setDark: { SystemAppearance.setDark($0, onLog: onLog) },
            rearmAuto: { SystemAppearance.rearmAuto() },
            readDebt: {
                UserDefaults.standard.data(forKey: debtKey).flatMap {
                    try? JSONDecoder().decode(
                        VisionAppearanceDebt.self,
                        from: $0
                    )
                }
            },
            writeDebt: { debt in
                guard let debt else {
                    UserDefaults.standard.removeObject(forKey: debtKey)
                    return true
                }
                guard let data = try? JSONEncoder().encode(debt) else {
                    return false
                }
                UserDefaults.standard.set(data, forKey: debtKey)
                return true
            }
        )
    }

    /// Reads light, never switches, and keeps its debt in memory.
    static func inert() -> VisionAppearanceSwitch {
        let store = InertDebtStore()
        return VisionAppearanceSwitch(
            read: { SystemAppearance.State(dark: false, auto: false) },
            setDark: { _ in true },
            rearmAuto: {},
            readDebt: { store.debt },
            writeDebt: {
                store.debt = $0
                return true
            }
        )
    }
}

/// The inert switch's debt, held for the life of its core.
@MainActor
final class InertDebtStore {
    var debt: VisionAppearanceDebt?
}
