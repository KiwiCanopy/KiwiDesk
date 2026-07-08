import Foundation

/// Shared across the settings sections (name fields, add rows,
/// save dialogs) — a neutral home so no feature file owns it.
extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
