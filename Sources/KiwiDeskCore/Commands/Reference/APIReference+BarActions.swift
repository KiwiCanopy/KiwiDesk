import Foundation

/// The bars' show/hide action (#761), split from `APIReference`
/// for the file ceiling.
extension APIReference {
    /// The verbs `space_bar` and `app_bar` carry beside a setter
    /// per field (#761): the show/hide action, which writes
    /// nothing stored.
    public static let barActions = ["toggle_reveal"]

    /// The bar a `space_bar.` / `app_bar.` action names, nil for
    /// any other command — the dispatch's one reading of
    /// `barActions`.
    static func barAction(of command: String) -> ShelfBar? {
        for (prefix, bar) in [
            ("space_bar.", ShelfBar.space), ("app_bar.", .app),
        ]
        where command.hasPrefix(prefix)
            && barActions.contains(String(command.dropFirst(prefix.count)))
        {
            return bar
        }
        return nil
    }
}
