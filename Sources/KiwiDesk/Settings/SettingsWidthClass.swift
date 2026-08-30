import SwiftUI

/// Settings window responsive width bands (#678,
/// `SettingsResponsiveOrderTests`).
enum SettingsWidthClass: String, CaseIterable, Sendable {
    case wide
    case medium
    case compact
    case tight

    /// The ruled breakpoints and the hard minimum, public so the
    /// shell and the tests read the same numbers — a second copy
    /// of 720 anywhere is the drift this enum exists to prevent.
    static let panelBreakpoint: CGFloat = 1200
    static let rowBreakpoint: CGFloat = 900
    static let chromeBreakpoint: CGFloat = 820
    static let minimum: CGFloat = 720
    /// Minimum content height — one fact with two axes, homed
    /// beside `minimum` so surfaces derive from it rather than
    /// restate it (#859); the window controller's opening HEIGHT
    /// is still a bare literal, deliberately unclaimed.
    static let minimumHeight: CGFloat = 540

    static func of(width: CGFloat) -> SettingsWidthClass {
        if width >= panelBreakpoint { return .wide }
        if width >= rowBreakpoint { return .medium }
        if width >= chromeBreakpoint { return .compact }
        return .tight
    }

    /// Whether preview panel docks into its own column beside content.
    var docksPanel: Bool { self == .wide }

    /// Whether detached preview card defaults to open without explicit summon.
    var floatsPreviewByDefault: Bool { self == .medium }

    /// Whether labelled row stacks its control beneath the label.
    var stacksRows: Bool { self == .compact || self == .tight }

    /// Whether save pill anchors into persistent footer bar.
    var docksSavePill: Bool { stacksRows }

    /// Whether header search field collapses into an icon button.
    var collapsesChrome: Bool { self == .tight }

    /// Maximum columns for Home card grid.
    var homeColumnCap: Int {
        switch self {
        case .wide: return 4
        case .medium: return 3
        case .compact, .tight: return 2
        }
    }

    /// Maximum columns for preset card grid (#789).
    var presetColumnCap: Int { max(1, homeColumnCap - 1) }
}

private struct SettingsWidthClassKey: EnvironmentKey {
    static let defaultValue = SettingsWidthClass.wide
}

extension EnvironmentValues {
    /// Injected width band from root `SettingsView` geometry.
    var settingsWidth: SettingsWidthClass {
        get { self[SettingsWidthClassKey.self] }
        set { self[SettingsWidthClassKey.self] = newValue }
    }
}
