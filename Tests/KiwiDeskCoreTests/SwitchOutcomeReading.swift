import Foundation

@testable import KiwiDeskCore

/// The switch verbs' payload, read the way a CALLER reads it
/// (#1336) — the CLI over JSON, Lua over the mapped table.
///
/// Shared because the reading is the thing under test in two
/// places at once: the outcome's own suite builds the enum, and
/// `DesktopCommandTests` drives the verbs that return it. A copy
/// per suite would let the two disagree about what a caller
/// sees, which is the divergence this whole change closes.
enum SwitchOutcomeReading {
    /// `switched`, or nil where the payload does not carry it —
    /// which is what a consumer dropping `.response` produces,
    /// and so must stay distinguishable from `false`.
    static func switched(_ response: CommandResponse) -> Bool? {
        guard case .object(let payload)? = response.data,
            case .bool(let value)? = payload["switched"]
        else { return nil }
        return value
    }

    /// The stand-down's note, nil when absent.
    static func note(_ response: CommandResponse) -> String? {
        guard case .object(let payload)? = response.data,
            case .string(let value)? = payload["note"]
        else { return nil }
        return value
    }
}
