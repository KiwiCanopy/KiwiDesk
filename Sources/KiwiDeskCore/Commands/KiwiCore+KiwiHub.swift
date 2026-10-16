import Foundation

/// KiwiHub's three sides, in the order of their keys J K L
/// (#2246, #2265, #2309): the window switcher, the shortcuts panel
/// and the view picker.
public enum KiwiHubSide: String, Sendable, CaseIterable, Equatable {
    case windows
    case shortcuts
    case view

    /// The Lua a binding runs to open this side — the one spelling
    /// the seed, the Settings rows and the panel's chord labels
    /// share.
    public var lua: String { "kiwihub.show(\"\(rawValue)\")" }
}

extension KiwiHubSide: APIChoiceType {}

extension KiwiCore {
    /// The `kiwihub.*` verbs (#2265). `show` opens KiwiHub on a
    /// side, switches it there, or closes it when that side is
    /// up; the GUI answers through `uiBridge`. No window moves,
    /// so no retile.
    func kiwiHubCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "kiwihub.show":
            guard let raw = args.first?.stringValue,
                let side = KiwiHubSide(rawValue: raw)
            else { return CommandResponse.expected(KiwiHubSide.self) }
            uiBridge.onKiwihubShow(side)
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }
}
