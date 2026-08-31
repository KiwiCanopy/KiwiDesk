/// Application version and build commit constants (`scripts/bump-version.sh`,
/// `ScriptStampTests`, #32).
public enum KiwiDeskVersion {
    /// Semantic version, bumped per release.
    public static let semantic = "1.1.2"

    /// Short commit SHA of the build, stamped during release (#32).
    public static let commit = "unknown"

    /// Version and commit, for `kiwidesk --version` — its one
    /// reader (#1174, `VersionDisplayTests`).
    public static var displayString: String {
        commit == "unknown"
            ? semantic
            : "\(semantic) (\(commit))"
    }
}
