import CoreGraphics
import Foundation

/// App bar nested option vocabularies (split from `AppBarStyle.swift`).
extension AppBarStyle {
    /// Minimum bar thickness in pt (QA 2026-07-19).
    public static let minThickness: CGFloat = 20

    /// True if platform supports Liquid Glass (macOS 26+, #390).
    public static var glassAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Background drawing style.
    public enum BackgroundStyle: String, Sendable, Codable, CaseIterable {
        case boxed
        case plain
    }

    /// Background plate fit (QA 2026-07-19).
    public enum BackgroundFit: String, Sendable, Codable, CaseIterable {
        case full
        case hug
    }

    /// Active item indicator style.
    public enum ActiveIndicator: String, Sendable, Codable, CaseIterable {
        case outline
        case edgeMark = "edge_mark"
        case gap
    }

    /// Content drawn per item (owner 2026-08-19, #160).
    /// `CaseIterable` guarded by `BarTitleCapTests.showsTextIsExhaustive`.
    public enum Content: String, Sendable, Codable, CaseIterable {
        case icon
        case title
        case iconAndTitle = "icon_and_title"

        /// Content actually rendered, collapsing vertical to `.icon`
        /// (QA 2026-07-19).
        public func rendered(horizontal: Bool) -> Content {
            horizontal ? self : .icon
        }

        /// True if content displays text.
        public var showsText: Bool { self != .icon }
    }

    /// Item group alignment along the bar's axis (#293 QA).
    public enum BarAlignment: String, Sendable, Codable,
        CaseIterable
    {
        case start
        case center
        case end
    }
}
