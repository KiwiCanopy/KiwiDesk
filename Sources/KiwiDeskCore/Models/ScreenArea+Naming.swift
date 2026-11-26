import Foundation

/// Why a name cannot be given to a screen area (#3517 ruling 16):
/// an argument resolves a number as a screen and an area's name
/// beside screen names, so either clash would make one of them
/// unreachable.
public enum ScreenAreaNameProblem: Equatable, Sendable {
    case number
    case taken
}

extension ScreenArea {
    /// The rule a name for the area `key` breaks, nil when it may
    /// take it: never all digits, never a name another area of
    /// `splits` or a screen in `screenNames` already has. An empty
    /// name clears and breaks none.
    public static func nameProblem(
        _ name: String,
        for key: ScreenAreaKey,
        splits: [String: ScreenSplit],
        screenNames: [String]
    ) -> ScreenAreaNameProblem? {
        guard !name.isEmpty else { return nil }
        // `N#id` names Screen N's area in Lua (#3647), so it is a
        // number too.
        if name.allSatisfy(\.isNumber) || ScreenSlotKey(parsing: name) != nil {
            return .number
        }
        let otherArea = splits.contains { fingerprint, split in
            split.areas.contains {
                $0.name == name
                    && ScreenAreaKey(fingerprint: fingerprint, areaID: $0.id)
                        != key
            }
        }
        return otherArea || screenNames.contains(name) ? .taken : nil
    }
}
