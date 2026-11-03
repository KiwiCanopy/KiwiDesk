import Foundation

/// Whether a name for a saved palette or look may be used (#2953):
/// the one rule a Save or Rename button, its caption, Core's write
/// doors and the stores' rename all read.
public enum LibraryNameVerdict: Equatable, Sendable {
    /// No saved entry holds the name; a rename to its own name.
    case free
    /// A save that replaces the user's entry of that name.
    case overwrites
    case blank
    /// A bundled entry's name, which no user entry may take.
    case bundled
    /// A rename onto another user entry's name.
    case taken

    public var isAllowed: Bool { self == .free || self == .overwrites }

    /// `typed` as a library stores it: trimmed.
    public static func normalized(_ typed: String) -> String {
        typed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The verdict on `name` exactly as given; a caller holding typed
    /// text hands it `normalized` first.
    static func judge(
        _ name: String,
        renaming old: String?,
        bundled: (String) -> Bool,
        saved: (String) -> Bool
    ) -> LibraryNameVerdict {
        if name.isEmpty { return .blank }
        if bundled(name) { return .bundled }
        guard saved(name) else { return .free }
        guard let old else { return .overwrites }
        return name == old ? .free : .taken
    }
}

/// A save or rename refused for its name (#2953).
public struct LibraryNameRefusal: Error, Equatable {
    public let verdict: LibraryNameVerdict
}
