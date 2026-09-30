import CoreGraphics
import Foundation

/// App bar nested option vocabularies (split from `AppBarStyle.swift`).
extension AppBarStyle {
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
