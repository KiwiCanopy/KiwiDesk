import Foundation
import KiwiDeskCore

/// One event line as `kiwidesk watch` hands it to a command: the
/// name and data JSON, plus each top-level scalar of the data under
/// its own name (#1685 ▸ Ruling 6e).
struct CLIWatchEvent: Equatable {
    static let prefix = "KIWIDESK_"
    static let eventKey = prefix + "EVENT"
    static let dataKey = prefix + "DATA"

    let name: String
    let data: [String: JSONValue]

    /// Nil for any line that is not an event — the stream's
    /// confirmation, or a line that is not JSON.
    init?(line: String) {
        guard
            case .object(let object) = Self.decode(line),
            let name = object["event"]?.stringValue
        else { return nil }
        self.name = name
        if case .object(let data) = object["data"] {
            self.data = data
        } else {
            self.data = [:]
        }
    }

    /// The variables the command runs with. The two fixed names
    /// win over a data key that would spell them.
    var environment: [String: String] {
        var result: [String: String] = [:]
        for (key, value) in data {
            if let text = value.scalarText {
                result[Self.variable(for: key)] = text
            }
        }
        result[Self.eventKey] = name
        result[Self.dataKey] =
            CLIOutput.render(.object(data), pretty: false) ?? "{}"
        return result
    }

    /// `space_id` → `KIWIDESK_SPACE_ID`; anything not a letter or a
    /// digit becomes `_`.
    static func variable(for key: String) -> String {
        let name = key.uppercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
                ? Character(scalar) : "_"
        }
        return prefix + String(name)
    }

    /// The names a confirmation line says the app did not know.
    static func unknownNames(in line: String) -> String? {
        guard
            case .object(let object) = decode(line),
            case .object(let data) = object["data"],
            case .array(let unknown) = data["unknown"],
            !unknown.isEmpty
        else { return nil }
        return unknown.compactMap(\.stringValue).joined(separator: ", ")
    }

    private static func decode(_ line: String) -> JSONValue? {
        try? JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
    }
}
