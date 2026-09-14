import AppKit
import Foundation

/// One macOS setting the checklist reads (#1365): where it is
/// stored, what "done" is, and what an ABSENT key means — the
/// shipped default, never "unknown" (values read on macOS 26.6,
/// 2026-09-14; `MacSettingReadTests`). GUI-boundary like
/// `SystemShortcutEnablement`, reached only through the
/// `SettingsModel.readMacSetting` seam.
enum MacSetting: String, CaseIterable, Hashable {
    case rearrangeSpaces
    case switchOnActivate
    case stageManager
    case edgeTiling
    case clickWallpaper
    case doubleClickTitle

    /// Preference domain; nil is the global domain (`defaults -g`).
    var domain: String? {
        switch self {
        case .rearrangeSpaces: return "com.apple.dock"
        case .switchOnActivate, .doubleClickTitle: return nil
        case .stageManager, .edgeTiling, .clickWallpaper:
            return "com.apple.WindowManager"
        }
    }

    var key: String {
        switch self {
        case .rearrangeSpaces: return "mru-spaces"
        case .switchOnActivate: return "AppleSpacesSwitchOnActivate"
        case .stageManager: return "GloballyEnabled"
        case .edgeTiling: return "EnableTilingByEdgeDrag"
        case .clickWallpaper:
            return "EnableStandardClickToShowDesktop"
        case .doubleClickTitle: return "AppleActionOnDoubleClick"
        }
    }

    /// What macOS ships when the key is absent.
    var absentValue: MacSettingValue {
        switch self {
        case .rearrangeSpaces, .switchOnActivate, .edgeTiling,
            .clickWallpaper:
            return .bool(true)
        case .stageManager: return .bool(false)
        case .doubleClickTitle: return .string("Fill")
        }
    }

    /// The stored value that ticks the row.
    var target: MacSettingValue {
        switch self {
        case .rearrangeSpaces, .switchOnActivate, .stageManager,
            .edgeTiling, .clickWallpaper:
            return .bool(false)
        case .doubleClickTitle: return .string("None")
        }
    }
}

/// A stored preference value the checklist can judge.
enum MacSettingValue: Hashable {
    case bool(Bool)
    case string(String)

    func isSameKind(as other: MacSettingValue) -> Bool {
        switch (self, other) {
        case (.bool, .bool), (.string, .string): return true
        case (.bool, .string), (.string, .bool): return false
        }
    }
}

/// What one read returned; `.other` is a value of a shape this
/// build does not know (a future macOS re-typing the key), which
/// the row reports as unreadable rather than as "Not yet".
enum MacSettingRaw: Hashable {
    case absent
    case value(MacSettingValue)
    case other
}

/// The row's verdict.
enum MacSettingState: Hashable {
    case set
    case notSet
    case unreadable
}

enum MacSettingRead {
    /// Reads the key from the user's preferences. A `defaults
    /// write -bool` lands as a CFBoolean and System Settings'
    /// own writes as an integer; both are numbers here.
    static func liveRead(_ setting: MacSetting) -> MacSettingRaw {
        let domain: CFString =
            setting.domain.map { $0 as CFString }
            ?? kCFPreferencesAnyApplication
        guard
            let raw = CFPreferencesCopyAppValue(
                setting.key as CFString,
                domain
            )
        else { return .absent }
        if let number = raw as? NSNumber {
            return .value(.bool(number.boolValue))
        }
        if let string = raw as? String {
            return .value(.string(string))
        }
        return .other
    }

    /// Classifies a read against the setting's target, absence
    /// standing in for the shipped default.
    static func state(
        of setting: MacSetting,
        reading raw: MacSettingRaw
    ) -> MacSettingState {
        switch raw {
        case .absent:
            return setting.absentValue == setting.target
                ? .set : .notSet
        case .value(let value):
            // A value of the OTHER kind — `defaults write` with no
            // `-bool` stores the string "false", which macOS
            // honours — is unreadable, never a false "Not yet".
            guard value.isSameKind(as: setting.target) else {
                return .unreadable
            }
            return value == setting.target ? .set : .notSet
        case .other:
            return .unreadable
        }
    }

    /// Every row lives in Desktop & Dock; sub-pane anchors are
    /// undocumented and move between releases, so the caption's
    /// breadcrumb carries the rest.
    static let desktopAndDockPane = URL(
        string:
            "x-apple.systempreferences:"
            + "com.apple.Desktop-Settings.extension"
    )!

    /// Opens System Settings at Desktop & Dock, plainly if the
    /// pane URL is refused — the app writes nothing there.
    @MainActor static func openDesktopAndDock() {
        if NSWorkspace.shared.open(desktopAndDockPane) { return }
        if let app = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) {
            NSWorkspace.shared.openApplication(
                at: app,
                configuration: .init()
            )
        }
    }
}
