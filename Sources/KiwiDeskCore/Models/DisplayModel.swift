import CoreGraphics
import Foundation

/// Identifier of a physical display (wraps `CGDirectDisplayID`).
public struct DisplayID: Hashable, Sendable, Codable,
    CustomStringConvertible
{
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public var description: String { "display#\(raw)" }
}

/// A snapshot of one connected monitor.
///
/// `fingerprint` uniquely identifies the hardware so profiles can
/// be re-applied when a known monitor setup is reconnected.
public struct Display: Sendable, Equatable {
    public let id: DisplayID
    public var name: String
    /// The screen's frame in AppKit's global coordinates, where
    /// **y grows UP** — so the screen physically above another has
    /// the LARGER `minY`, and an ascending sort on it reads
    /// bottom-to-top.
    ///
    /// Stated here because this is where every sorter starts, and
    /// two of them already got it wrong:
    /// `PositionalDisplays.ordered`'s comment still says "ties
    /// broken top-to-bottom" over an ascending `minY` (harmless
    /// there — any deterministic tiebreak serves positional
    /// addressing), and #752's first screen sort listed a stacked
    /// pair in reverse while claiming to match the Monitors
    /// picture. `DeskOrder` is the GUI's one reading-order rule and
    /// negates y for this reason.
    public var frame: CGRect
    /// Usable area (frame minus menu bar / Dock).
    public var visibleFrame: CGRect

    public init(
        id: DisplayID,
        name: String,
        frame: CGRect,
        visibleFrame: CGRect? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame ?? frame
    }

    /// Stable identity string based on name and resolution.
    public var fingerprint: String {
        let w = Int(frame.width)
        let h = Int(frame.height)
        return "\(name):\(w)x\(h)"
    }
}
