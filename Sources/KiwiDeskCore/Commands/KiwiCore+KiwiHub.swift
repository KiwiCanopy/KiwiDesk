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
    /// up; the GUI answers through `uiBridge`. `set_key` stores a
    /// navigation key's alternative (#2600), which the panel reads
    /// at each press. No window moves, so no retile.
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
        case "kiwihub.set_key":
            return setKiwiHubKey(args)
        default:
            return .fail("unknown command: \(command)")
        }
    }
}

extension KiwiCore {
    /// `kiwihub.set_key(key, combo)`: a missing or empty combo
    /// clears the alternative; one the panel cannot take is
    /// refused with its reason.
    fileprivate func setKiwiHubKey(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let key = KiwiHubKey(rawValue: raw)
        else { return CommandResponse.expected(KiwiHubKey.self) }
        let text = args.dropFirst().first?.stringValue ?? ""
        guard !text.isEmpty else {
            tiler.settings.kiwihub.key[key] = nil
            return .ok()
        }
        guard let combo = KeyCombo.parse(text),
            let canonical = combo.comboString()
        else { return .fail("expected a key combo, e.g. ctrl+n") }
        if let refusal = KiwiHubKeyRefusal.of(
            combo,
            as: key,
            in: tiler.settings.kiwihub.key
        ) {
            return .fail(refusal.message)
        }
        tiler.settings.kiwihub.key[key] = canonical
        return .ok()
    }
}
