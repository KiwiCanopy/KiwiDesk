import AppKit

/// The system's light/dark appearance, which KiwiVision may switch
/// while it is on (#2103 ruling 7). Read from the global
/// preferences System Settings writes; switched through SkyLight's
/// legacy theme call (no permission, measured in #2103's P5), with
/// System Events as the public fallback, which asks for Automation
/// once.
enum SystemAppearance {
    /// Light or dark, and whether macOS switches it by time of day.
    struct State: Codable, Equatable, Sendable {
        var dark: Bool
        var auto: Bool
    }

    typealias GetLegacyFn = @convention(c) () -> Bool
    typealias SetLegacyFn = @convention(c) (Bool) -> Void

    static let getLegacySymbol = SkyLight.symbol(
        "SLSGetAppearanceThemeLegacy",
        as: GetLegacyFn.self
    )
    static let setLegacySymbol = SkyLight.symbol(
        "SLSSetAppearanceThemeLegacy",
        as: SetLegacyFn.self
    )

    private static let styleKey = "AppleInterfaceStyle"
    private static let autoKey =
        "AppleInterfaceStyleSwitchesAutomatically"

    /// The live appearance, from the global preferences.
    static func read() -> State {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let style =
            CFPreferencesCopyAppValue(
                styleKey as CFString,
                kCFPreferencesAnyApplication
            ) as? String
        let auto =
            CFPreferencesCopyAppValue(
                autoKey as CFString,
                kCFPreferencesAnyApplication
            ) as? Bool ?? false
        return State(dark: style == "Dark", auto: auto)
    }

    /// Asks macOS for `dark`. Performed is not applied: a reader
    /// judges by the next `read()`. The fallback runs off the main
    /// actor — `osascript` waits on an Automation prompt.
    @MainActor
    static func setDark(
        _ dark: Bool,
        onLog: @escaping @MainActor (String) -> Void
    ) {
        if let set = setLegacySymbol.function {
            set(dark)
            return
        }
        Task.detached(priority: .userInitiated) {
            if let failure = runSystemEvents(dark: dark) {
                await MainActor.run { onLog(failure) }
            }
        }
    }

    /// Turns macOS's automatic switching back on, which a manual
    /// switch turns off. Unverified on a device (#2103).
    static func rearmAuto() {
        CFPreferencesSetValue(
            autoKey as CFString,
            kCFBooleanTrue,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    /// The public fallback; nil when it ran, else what failed
    /// (-1743 is Automation refused).
    private static func runSystemEvents(dark: Bool) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"System Events\" to tell "
                + "appearance preferences to set dark mode to \(dark)",
        ]
        process.standardOutput = FileHandle.nullDevice
        let error = Pipe()
        process.standardError = error
        guard (try? process.run()) != nil else {
            return "kiwivision: osascript did not start"
        }
        let detail = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return nil }
        return "kiwivision: appearance switch failed: "
            + String(decoding: detail, as: UTF8.self)
    }

    /// The `self_test` rows (#1889): the read is checked against
    /// the preferences; the switch is only looked up.
    @MainActor
    static func selfTestProbes() -> [PrivatePathProbe] {
        let home = "SystemAppearance"
        return [
            .read(getLegacySymbol.resolution, home: home) {
                guard let get = getLegacySymbol.function else {
                    return .absent
                }
                let theme = get()
                let preferences = read().dark
                return theme == preferences
                    ? .works("dark: \(theme)")
                    : .inconclusive(
                        "SkyLight dark: \(theme), "
                            + "preferences dark: \(preferences)"
                    )
            },
            .write(setLegacySymbol.resolution, home: home),
        ]
    }
}
