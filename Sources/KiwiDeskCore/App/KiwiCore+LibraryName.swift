import Foundation

/// Whether a name typed for a saved palette or look may be used
/// (#2953): the one answer a Save or Rename button, its caption and
/// the write it triggers all read.
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
}

/// A save or rename refused for its name (#2953).
public struct LibraryNameRefusal: Error, Equatable {
    public let verdict: LibraryNameVerdict
}

extension KiwiCore {
    /// The verdict on `typed`, trimmed, as a palette name; pass
    /// `renaming` the palette's current name for a rename.
    public func paletteNameVerdict(
        _ typed: String,
        renaming old: String? = nil
    ) -> LibraryNameVerdict {
        let library = paletteLibrary
        return Self.nameVerdict(
            typed,
            renaming: old,
            bundled: library.isBuiltinName,
            saved: library.hasUserPalette
        )
    }

    /// The verdict on `typed`, trimmed, as a look name; pass
    /// `renaming` the look's current name for a rename.
    public func lookNameVerdict(
        _ typed: String,
        renaming old: String? = nil
    ) -> LibraryNameVerdict {
        let library = lookLibrary
        return Self.nameVerdict(
            typed,
            renaming: old,
            bundled: library.isBuiltinName,
            saved: library.hasUserLook
        )
    }

    /// Throws `LibraryNameRefusal` unless `verdict` allows the write.
    func requireName(_ verdict: LibraryNameVerdict) throws {
        guard verdict.isAllowed else {
            throw LibraryNameRefusal(verdict: verdict)
        }
    }

    static func nameVerdict(
        _ typed: String,
        renaming old: String?,
        bundled: (String) -> Bool,
        saved: (String) -> Bool
    ) -> LibraryNameVerdict {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .blank }
        if bundled(name) { return .bundled }
        guard saved(name) else { return .free }
        guard let old else { return .overwrites }
        return name == old ? .free : .taken
    }
}
