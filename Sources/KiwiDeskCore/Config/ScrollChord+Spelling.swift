import Foundation

extension ScrollChord: Codable {
    /// Keybindings' modifier spelling (`KeyCombo.parse`), in their
    /// canonical order; the empty string is off.
    public var spelling: String {
        var parts: [String] = []
        if contains(.control) { parts.append("control") }
        if contains(.option) { parts.append("option") }
        if contains(.shift) { parts.append("shift") }
        if contains(.command) { parts.append("command") }
        return parts.joined(separator: "+")
    }

    /// Parses a spelling, keybindings' aliases included; nil on an
    /// unknown modifier or a repeated one.
    public init?(spelling text: String) {
        var chord: ScrollChord = []
        let parts = text.lowercased().split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts where !part.isEmpty {
            let modifier: ScrollChord
            switch part {
            case "control", "ctrl": modifier = .control
            case "option", "opt", "alt": modifier = .option
            case "command", "cmd": modifier = .command
            case "shift": modifier = .shift
            default: return nil
            }
            guard !chord.contains(modifier) else { return nil }
            chord.insert(modifier)
        }
        self = chord
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer()
            .decode(String.self)
        guard let chord = ScrollChord(spelling: text) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "unknown modifier in \(text)"
                )
            )
        }
        self = chord
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(spelling)
    }
}
