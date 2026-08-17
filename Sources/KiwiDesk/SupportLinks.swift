import Foundation

/// External support/branding links (#68 §3.9).
enum SupportLinks {
    /// The Ko-fi page, linked from the About card.
    ///
    /// This comment used to claim two surfaces — "quick menu +
    /// About" — and the quick menu has no support row, so it
    /// named a call site that does not exist. Nothing counts
    /// call sites, which is why a claim like that survives; the
    /// sentence is now just what the constant IS.
    static let koFi = URL(
        string: "https://ko-fi.com/kiwicanopy"
    )!

    /// The GitHub Releases page — KiwiDesk's changelog (#570).
    ///
    /// The releases ARE the changelog: this repo ships no
    /// `CHANGELOG.md`, and Sparkle — which would show notes on
    /// update — is not in the tree, so before this link the app
    /// could not tell a user what changed anywhere at all.
    ///
    /// **Linked for the notes, not as a download.**
    /// `docs/design-decisions.md` ▸ "No distribution channel
    /// without an update path" forbids advertising the Release
    /// ZIP as a direct download until Sparkle ships, and that
    /// rule governs what a surface PROMOTES; the ruling that a
    /// notes-labelled link does not open a download channel is
    /// in that same file, next to the rule it qualifies. So the
    /// label stays about the notes — do not retitle this to
    /// "Download" or point it at a release asset.
    static let releases = URL(
        string:
            "https://github.com/KiwiCanopy/KiwiDesk/releases"
    )!
}
