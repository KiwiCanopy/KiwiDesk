/// Application version and build commit constants (`scripts/bump-version.sh`,
/// `ScriptStampTests`, #32).
public enum KiwiDeskVersion {
    /// Semantic version, bumped per release.
    public static let semantic = "1.1.1"

    /// Short commit SHA of the build, stamped during release (#32).
    public static let commit = "unknown"

    /// Formatted version and commit display string.
    public static var displayString: String {
        commit == "unknown"
            ? semantic
            : "\(semantic) (\(commit))"
    }
}
