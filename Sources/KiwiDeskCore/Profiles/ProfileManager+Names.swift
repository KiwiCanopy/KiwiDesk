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
