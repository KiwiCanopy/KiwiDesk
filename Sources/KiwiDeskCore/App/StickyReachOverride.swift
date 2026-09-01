import Foundation

/// The focused window's Desktop-reach override wire values
/// (`override_sticky_reach`, #1145). `auto` clears back to the
/// global `sticky.desktop_reach` toggle.
public enum StickyReachOverride: String, CaseIterable, Sendable {
    case on
    case off
    case auto
}
