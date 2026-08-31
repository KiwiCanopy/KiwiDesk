/// Application version and build commit constants (#32). Keep
/// both declarations literally `let <name> = "<value>"`:
/// `scripts/bump-version.sh` rewrites them with `sed` matching
/// that exact shape and exits 0 having changed nothing when it
/// drifts — the script reads back what it wrote, and
/// `ScriptStampTests` holds that guard against the real file.
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
