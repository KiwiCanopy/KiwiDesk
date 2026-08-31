import Foundation

/// Locates SwiftPM resource bundles inside `.app` and bare binaries (#89).
/// Replaces `Bundle.module` to prevent signing failures and launch crashes.
public enum ResourceBundle {
    /// Locates resource bundle under `Bundle.main.resourceURL`,
    /// else `fallback`. `Bundle.module` resolves via a `.build`
    /// absolute path baked on the BUILD machine — it works there
    /// and `fatalError`s everywhere else, invisibly to every local
    /// test. Inside a `.app` a missing bundle must NOT fall through
    /// to the fallback autoclosure, which is `Bundle.module` at
    /// every call site: that would re-import the crash this type
    /// exists to remove.
    public static func locate(
        _ name: String,
        fallback: @autoclosure () -> Bundle
    ) -> Bundle {
        if let resources = Bundle.main.resourceURL {
            let url = resources.appendingPathComponent(
                "\(name).bundle"
            )
            if let bundle = Bundle(url: url) {
                return bundle
            }
            if Bundle.main.bundleURL.pathExtension == "app" {
                NSLog(
                    "KiwiDesk: resource bundle %@.bundle missing "
                        + "from the app bundle; falling back to "
                        + "built-in defaults.",
                    name
                )
                return .main
            }
        }
        return fallback()
    }
}

extension Bundle {
    /// Target bundle name for `KiwiDeskCore` (`ResourceBundleNameTests`).
    public static let kiwiDeskCoreName = "KiwiDesk_KiwiDeskCore"

    /// `KiwiDeskCore` resource bundle located via `ResourceBundle.locate`.
    public static let kiwiDeskCore: Bundle = ResourceBundle.locate(
        kiwiDeskCoreName,
        fallback: .module
    )
}
