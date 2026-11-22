import Foundation

/// The stored identity of a screen area (#3517 ruling 14): the
/// physical screen's `Display.fingerprint`, plus `#<id>` for every
/// area but the one holding id 0, which keeps the bare fingerprint
/// so no pin owes a migration when a screen is first split. The
/// suffix is never `:`, which `Display.fingerprintParts` splits on.
/// The one owner of building and parsing an area key.
public struct ScreenAreaKey: Hashable, Sendable,
    CustomStringConvertible
{
    public static let separator: Character = "#"

    public let fingerprint: String
    public let areaID: Int

    public init(fingerprint: String, areaID: Int = 0) {
        self.fingerprint = fingerprint
        self.areaID = areaID
    }

    /// The key as stored: a pin, a per-screen map key.
    public var description: String {
        areaID == 0
            ? fingerprint
            : "\(fingerprint)\(Self.separator)\(areaID)"
    }

    /// Parses a stored key. A trailing `#<digits>` names an area
    /// only after a `name:WxH` fingerprint; anything else is a bare
    /// fingerprint, so a screen name holding `#` stays whole.
    public init(parsing raw: String) {
        if let mark = raw.lastIndex(of: Self.separator) {
            let head = String(raw[..<mark])
            let tail = raw[raw.index(after: mark)...]
            if let id = Int(tail), id > 0, tail.allSatisfy(\.isASCII),
                Self.isFingerprint(head)
            {
                self.init(fingerprint: head, areaID: id)
                return
            }
        }
        self.init(fingerprint: raw)
    }

    /// Whether `raw` has a fingerprint's `name:WxH` shape.
    static func isFingerprint(_ raw: String) -> Bool {
        let size = Display.fingerprintParts(raw).size
        let sides = size.split(
            separator: "x",
            omittingEmptySubsequences: false
        )
        return sides.count == 2
            && sides.allSatisfy { side in
                !side.isEmpty
                    && side.allSatisfy { $0.isASCII && $0.isNumber }
            }
    }
}
