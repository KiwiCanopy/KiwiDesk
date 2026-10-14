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
/// found and the one it asked for. Stored before the switch, so a
/// quit or crash leaves it for the next start.
struct VisionAppearanceDebt: Codable, Equatable, Sendable {
    var found: SystemAppearance.State
    var setDark: Bool
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
    var setDark: @MainActor (Bool) -> Void
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
            setDark: { _ in },
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
