import KiwiDeskCore
import SwiftUI

/// The GUI boundary where a Core `ProfileBrokenCause` becomes a
/// sentence (#96/#601) — `Conflict` → `ConflictText`,
/// `ConfigIssue.Kind` → `ConfigIssueText`, mirrored a third time.
///
/// ONE renderer for both surfaces that name a broken profile: the
/// Settings row under App ▸ Profiles and the Config Issues panel.
/// They used to carry two hand-written strings about one file, and
/// two strings about one condition are two places for it to be
/// described differently — which is what happened, the panel
/// saying "Couldn't be loaded" while the row said "Can't load".
///
/// Each sentence answers the question the row actually raises,
/// which is not "what broke" but **"is opening this file worth
/// it?"** (#678 Phase 4 pass 9, turn 18: the row says which of the
/// causes it was so the file is worth opening). That is why the
/// malformed case says the damage is visible and the shape case
/// does not promise it.
enum ProfileBrokenText {
    /// The sentence for one cause, in the user's language.
    @MainActor
    static func message(for cause: ProfileBrokenCause) -> String {
        switch cause {
        case .malformedJSON:
            return L(
                "profiles.broken.malformed",
                "Couldn't load — the file isn't valid JSON. "
                    + "Opening it will show where it broke."
            )
        case .unexpectedShape:
            return L(
                "profiles.broken.unexpected_shape",
                "Couldn't load — saved by another version, or a "
                    + "hand edit changed one of its fields."
            )
        case .unreadable:
            return L(
                "profiles.broken.unreadable",
                "Couldn't be read — the file may have been moved "
                    + "or deleted."
            )
        }
    }
}
