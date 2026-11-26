import Foundation

/// A stored Screen pin's target by number (#3647): the profile's
/// Screen `number`, or one of its areas. Stored as `"N"` or
/// `"N#<areaID>"`, the way `ScreenAreaKey` spells a fingerprint's;
/// the runtime keys pins by fingerprint, and `ScreenOrder` crosses
/// between the two.
public struct ScreenSlotKey: Hashable, Sendable, Comparable,
    CustomStringConvertible, Codable
{
    /// 1-based screen number.
    public let number: Int
    /// 0 for the whole screen, else an area id (#3517).
    public let areaID: Int

    /// Nil for a number below 1 or a negative area id.
    public init?(number: Int, areaID: Int = 0) {
        guard number >= 1, areaID >= 0 else { return nil }
        self.number = number
        self.areaID = areaID
    }

    /// Parses a stored key; nil for anything but `N` or `N#id`,
    /// digits only, no leading zero.
    public init?(parsing raw: String) {
        let parts = raw.split(
            separator: ScreenAreaKey.separator,
            omittingEmptySubsequences: false
        )
        guard parts.count <= 2,
            let number = Self.digits(parts[0])
        else { return nil }
        var area = 0
        if parts.count == 2 {
            guard let id = Self.digits(parts[1]), id > 0 else {
                return nil
            }
            area = id
        }
        self.init(number: number, areaID: area)
    }

    public var description: String {
        areaID == 0
            ? "\(number)"
            : "\(number)\(ScreenAreaKey.separator)\(areaID)"
    }

    /// The same screen number, whole.
    public var screen: ScreenSlotKey {
        ScreenSlotKey(number: number)!
    }

    public static func < (a: ScreenSlotKey, b: ScreenSlotKey) -> Bool {
        (a.number, a.areaID) < (b.number, b.areaID)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = ScreenSlotKey(parsing: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "not a screen number: \(raw)"
            )
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    private static func digits(_ part: Substring) -> Int? {
        guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
            part.first != "0" || part.count == 1,
            let value = Int(part)
        else { return nil }
        return value
    }
}
