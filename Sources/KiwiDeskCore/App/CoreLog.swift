import Foundation
import os

/// Unified log subsystem string (`subsystem == "com.kiwicanopy.kiwidesk"`).
public enum KiwiLog {
    public static let subsystem = "com.kiwicanopy.kiwidesk"
}

/// Unified-log write under `onLog` seams in Core and `KiwiCore.onLog`
/// (`core-boundaries.md`, `LogSeamWiringTests`, `LogSeamDefaultTests`).
enum CoreLog {
    /// Unified logger with `.public` privacy
    /// (macOS redacts `NSLog`, 2026-08-23).
    private static let logger = Logger(
        subsystem: KiwiLog.subsystem,
        category: "core"
    )

    /// Writes diagnostic line to unified log. The `KiwiDesk: `
    /// prefix is load-bearing: capture tooling greps for it, so
    /// changing it breaks log capture (`LogSeamSinkTests`, #624).
    static func write(_ message: String) {
        logger.log(
            "KiwiDesk: \(message, privacy: .public)"
        )
    }
}
