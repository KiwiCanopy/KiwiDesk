import Foundation
import KiwiDeskCore

/// Names completion reads from the running app: Space ids, window
/// ids, profile and look names (#1685 ▸ Ruling 6e). One bounded
/// request per completion, and nothing when the app does not
/// answer.
struct CLILiveValues {
    enum Source: CaseIterable, Equatable {
        case spaces
        case windows
        case profiles
        case looks
        /// The looks a user saved, which alone may be deleted.
        case savedLooks
        /// The screens of every stored setup (#3324).
        case storedScreens
    }

    /// A text argument whose values are a live source's names,
    /// keyed by command and argument. A name here that no record
    /// carries is a guard's to catch (`CLICompleterTests`).
    static let textSources: [String: [String: Source]] = [
        "load_profile": ["name": .profiles],
        "save_profile": ["name": .profiles],
        "delete_profile": ["name": .profiles],
        "forget_monitor_set": ["screen": .storedScreens],
        "set_default_profile": ["name": .profiles],
        "bind_profile_to_desktop": ["profile": .profiles],
        "look.apply": ["name": .looks],
        "look.delete": ["name": .savedLooks],
    ]

    /// Seconds a completion waits for the app.
    static let answerTimeout = 1

    var send: (CommandRequest) -> CommandResponse? = { request in
        try? AppSocket.connect(timeout: CLILiveValues.answerTimeout)
            .roundTrip(request)
    }

    func names(_ source: Source) -> [String] {
        guard let data = send(Self.request(for: source))?.data else {
            return []
        }
        return Self.names(source, in: data)
    }

    static func request(for source: Source) -> CommandRequest {
        switch source {
        case .spaces, .windows:
            return CommandRequest(command: "get_state")
        case .profiles:
            return CommandRequest(command: "list_profiles")
        case .looks, .savedLooks:
            return CommandRequest(command: "look.list")
        case .storedScreens:
            return CommandRequest(command: "list_monitor_sets")
        }
    }

    /// The names in a source's answer.
    static func names(_ source: Source, in data: JSONValue) -> [String] {
        switch source {
        case .spaces:
            return field("id", of: data["spaces"])
        case .windows:
            return field("id", of: data["windows"])
        case .profiles:
            guard case .array(let rows) = data else { return [] }
            return rows.compactMap(\.stringValue)
        case .looks:
            return field("name", of: data["looks"])
        case .savedLooks:
            guard case .array(let rows)? = data["looks"] else { return [] }
            let saved = rows.filter { $0["bundled"] != .bool(true) }
            return field("name", of: .array(saved))
        case .storedScreens:
            guard case .array(let rows) = data else { return [] }
            let screens = rows.flatMap { row -> [String] in
                guard case .array(let names)? = row["screens"] else {
                    return []
                }
                return names.compactMap(\.stringValue)
            }
            return Array(Set(screens)).sorted()
        }
    }

    private static func field(
        _ key: String,
        of rows: JSONValue?
    ) -> [String] {
        guard case .array(let rows)? = rows else { return [] }
        return rows.compactMap { row in
            row[key]?.scalarText
        }
    }
}
