import Foundation
import KiwiDeskCore

/// A list joined in the APP's locale (#812 session 3, #1436).
/// `ListFormatter`'s class method joins in `Locale.current`, which
/// put a German "und" inside an English sentence on a German Mac;
/// every joined list in this tree takes this one door.
enum LocalizedList {
    @MainActor
    static func join(_ names: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = Locale(
            identifier:
                LocalizationManager.shared.effectiveLocale ?? "en"
        )
        return formatter.string(from: names)
            ?? names.joined(separator: ", ")
    }
}
