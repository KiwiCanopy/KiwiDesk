import KiwiDeskCore
import SwiftUI

/// The one renderer converting `ProfileBrokenCause` into localized text
/// for Settings and Config Issues (#96, #601, #678).
enum ProfileBrokenText {
    /// The sentence for one cause, in the user's language.
    @MainActor
    static func message(for cause: ProfileBrokenCause) -> String {
        switch cause {
        case .malformedJSON:
            return L(
                "profiles.broken.malformed",
                "Not valid JSON — opening it will show where it "
                    + "broke."
            )
        case .unexpectedShape:
            return L(
                "profiles.broken.unexpected_shape",
                "Saved by another version, or a hand edit changed "
                    + "one of its fields."
            )
        case .unreadable:
            return L(
                "profiles.broken.unreadable",
                "The file may have been moved or deleted."
            )
        }
    }
}
