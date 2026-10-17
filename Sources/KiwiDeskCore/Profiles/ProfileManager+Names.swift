import Foundation

/// Profile names: the free-name suffix and the filename check.
extension ProfileManager {
    /// Next available case-insensitive name suffix (`base`, `base_1`, ...)
    /// (#53, APFS case safety).
    public func freeName(base: String) -> String {
        let taken = Set(list().map { $0.lowercased() })
        guard taken.contains(base.lowercased()) else {
            return base
        }
        var suffix = 1
        while taken.contains(
            "\(base)_\(suffix)".lowercased()
        ) {
            suffix += 1
        }
        return "\(base)_\(suffix)"
    }

    /// The name a "Save as New Profile…" writes for `typed`:
    /// trimmed, then made free, so a taken name saves beside it
    /// and never over it; nil where it names no profile. The one
    /// home both Settings and KiwiHub ask (#2359).
    public func newProfileName(typed: String) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidName(trimmed) else { return nil }
        return freeName(base: trimmed)
    }

    /// Validates profile filename boundaries (no slashes, nulls, dot-files).
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return !trimmed.isEmpty
            && !name.contains("/")
            && !name.contains("\0")
            && !name.hasPrefix(".")
    }
}
