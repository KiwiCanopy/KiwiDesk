import Foundation

/// Finds a SwiftPM resource bundle inside a real `.app` (#89).
///
/// SwiftPM's generated `Bundle.module` accessor looks for
/// `<name>.bundle` under `Bundle.main.bundleURL`. For the bare
/// executable that is the executable's own directory and it
/// works. Inside an `.app` it is the **bundle root** — the
/// sibling of `Contents/` — and macOS refuses to sign a bundle
/// with anything loose there ("unsealed contents present in the
/// bundle root", leaving `Sealed Resources=none`). So the one
/// location `Bundle.module` accepts is the one a distributable
/// app cannot use, and the resources have to live in the
/// conventional `Contents/Resources` instead.
///
/// The failure this prevents is invisible on a dev machine:
/// `Bundle.module`'s second candidate is an **absolute path into
/// the `.build` directory that compiled it**, so on the machine
/// that built it the bundle always resolves and the layout looks
/// correct. Ship it, or just delete `.build`, and the accessor
/// hits neither candidate and calls `fatalError` — a crash at
/// first access, not a quiet fallback to defaults.
///
/// Resolution therefore prefers `Bundle.main.resourceURL`, and
/// falls back to the caller's own `Bundle.module` so bare
/// executables and `swift test` are unaffected. `Bundle.module`
/// is per-target and cannot be reached from here, which is why
/// callers pass their own — see `Bundle.kiwiDeskCore` below and
/// its GUI twin.
public enum ResourceBundle {
    /// - Parameters:
    ///   - name: bundle name without the `.bundle` extension,
    ///     e.g. `KiwiDesk_KiwiDeskCore`.
    ///   - fallback: the caller's own `Bundle.module`, used only
    ///     outside an `.app` — for the bare executable and
    ///     `swift test`, where it resolves normally.
    /// - Returns: the bundle found under
    ///   `Bundle.main.resourceURL`; inside an `.app` with the
    ///   bundle missing, `Bundle.main` (whose lookups simply
    ///   return nil); otherwise `fallback`.
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
            // Inside an `.app` the resources are supposed to be
            // right there, so a miss means a broken bundle. Do
            // NOT fall through to `Bundle.module` here: its
            // accessor `fatalError`s on any machine that did not
            // build it, which would turn a missing file into a
            // launch crash. Every caller is written to degrade
            // (`AppFontGlyphMap` promises "never a crash"), and
            // an empty bundle lets them.
            if Bundle.main.bundleURL.pathExtension == "app" {
                return .main
            }
        }
        return fallback()
    }
}

extension Bundle {
    /// `KiwiDeskCore`'s resources — locales, palettes, app font.
    /// Use this instead of `Bundle.module` inside this target.
    public static let kiwiDeskCore: Bundle = ResourceBundle.locate(
        "KiwiDesk_KiwiDeskCore",
        fallback: .module
    )
}
