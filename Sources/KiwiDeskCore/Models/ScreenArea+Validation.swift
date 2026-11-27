import CoreGraphics
import Foundation

/// Why a screen's area list is refused (#3517 ruling 13). Lua
/// refuses only broken input; Settings floors higher on its own.
public enum ScreenAreaProblem: Equatable, Sendable {
    case empty
    case duplicateID(Int)
    case negativeID(Int)
    case tooSmall(id: Int)
    case outsideScreen(id: Int)
    case overlap(Int, Int)
    case gap
    /// No full-span cut separates the areas (a pinwheel), so no
    /// dividers can be derived (ruling 20).
    case notGuillotine
    /// No area holds id 0 as the first in reading order, so nothing
    /// answers to the screen's bare fingerprint (rulings 14, 22).
    case missingLeadArea
}

extension ScreenArea {
    /// The first problem with `areas` as the split of a screen
    /// `width` × `height` points, or nil when they tile it exactly:
    /// every area inside the screen, none below `minimumSide` (the
    /// points floor unless a caller names its own), no
    /// two overlapping, their sizes adding up to the screen, and
    /// every cut full-span (a nested split is fine, #3541).
    public static func problem(
        with areas: [ScreenArea],
        width: Int,
        height: Int,
        minimumSide: Int = ScreenArea.minimumSide
    ) -> ScreenAreaProblem? {
        guard !areas.isEmpty else { return .empty }
        var seen = Set<Int>()
        for area in areas {
            if area.id < 0 { return .negativeID(area.id) }
            if !seen.insert(area.id).inserted {
                return .duplicateID(area.id)
            }
            if area.w < minimumSide || area.h < minimumSide {
                return .tooSmall(id: area.id)
            }
            if area.x < 0 || area.y < 0
                || area.x + area.w > width
                || area.y + area.h > height
            {
                return .outsideScreen(id: area.id)
            }
        }
        for (i, a) in areas.enumerated() {
            for b in areas[(i + 1)...] where a.rect.intersects(b.rect) {
                return .overlap(a.id, b.id)
            }
        }
        guard ScreenArea.readingOrder(areas).first?.id == 0 else {
            return .missingLeadArea
        }
        let covered = areas.reduce(0) { $0 + $1.w * $1.h }
        guard covered == width * height else { return .gap }
        let cuts = ScreenAreaCuts.cuts(
            of: areas,
            width: width,
            height: height
        )
        return cuts == nil ? .notGuillotine : nil
    }
}
