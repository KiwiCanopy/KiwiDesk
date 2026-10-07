import SwiftUI

/// A group the Shortcuts & Gestures jump chips lead to (#1520), in
/// page order. Layers takes no chip: it scopes the groups below
/// rather than being a destination, and is absent in Simple.
enum ShortcutsJumpGroup: CaseIterable, Hashable, Sendable {
    case gestures
    case focus
    case moveWindows
    case sizeFloat
    case openApplications

    /// The group's own title control: its text is the chip's
    /// label and its id the card's scroll anchor, so a chip can
    /// name nothing its card does not.
    @MainActor var control: SettingsControl {
        switch self {
        case .gestures: return SettingsCatalog.shortcuts.gestures.control
        case .focus: return SettingsCatalog.shortcuts.focusKeys
        case .moveWindows: return SettingsCatalog.shortcuts.moveWindows
        case .sizeFloat: return SettingsCatalog.shortcuts.sizeFloat
        case .openApplications:
            return SettingsCatalog.shortcuts.openApplications
        }
    }

    /// The chip a rule follows: everything after it is scoped to
    /// one layer, this card to none.
    var ruledAfter: Bool { self == .gestures }
}

/// What the pinned bar reads off the page's geometry: which group
/// is current and whether content has slid under the bar.
struct ShortcutsJumpReading: Equatable {
    var marked: ShortcutsJumpGroup?
    var underlapped = false

    /// How far below the bar a header may sit and still count as
    /// the one under it — the scroll content's top margin plus
    /// the slack a jump's landing leaves.
    static let reach: CGFloat = SettingsMetrics.paneInset + 8

    /// Frames are in the scroll viewport's space, so `minY` 0 is
    /// the bar's lower edge. The current group is the last whose
    /// header has reached the bar while its card is still under
    /// it; at the end of a scroll it is the last group, whose
    /// header may never reach the bar.
    static func read(
        _ frames: [ShortcutsJumpSlot: CGRect]
    ) -> ShortcutsJumpReading {
        var reading = ShortcutsJumpReading()
        if let content = frames[.content] {
            reading.underlapped = content.minY < 0
        }
        let reached = ShortcutsJumpGroup.allCases.last { group in
            guard let frame = frames[.group(group)] else {
                return false
            }
            return frame.minY <= reach
        }
        if let reached,
            let frame = frames[.group(reached)],
            frame.maxY > reach
        {
            reading.marked = reached
        }
        if atEnd(frames) {
            reading.marked = ShortcutsJumpGroup.allCases.last {
                frames[.group($0)] != nil
            }
        }
        return reading
    }

    /// Scrolled to the bottom of content taller than the viewport.
    private static func atEnd(
        _ frames: [ShortcutsJumpSlot: CGRect]
    ) -> Bool {
        guard let content = frames[.content],
            let viewport = frames[.viewport]
        else { return false }
        return content.minY < 0 && content.maxY <= viewport.maxY + 1
    }
}

/// One measured place on the page.
enum ShortcutsJumpSlot: Hashable, Sendable {
    case group(ShortcutsJumpGroup)
    case content
    case viewport
}

/// The measured frames, gathered up to the section.
struct ShortcutsJumpFrames: PreferenceKey {
    static let defaultValue: [ShortcutsJumpSlot: CGRect] = [:]

    static func reduce(
        value: inout [ShortcutsJumpSlot: CGRect],
        nextValue: () -> [ShortcutsJumpSlot: CGRect]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Reports this view's frame in the scroll viewport's space.
    func shortcutsJumpSlot(_ slot: ShortcutsJumpSlot) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ShortcutsJumpFrames.self,
                    value: [
                        slot: proxy.frame(
                            in: .named(ShortcutsJumpSlot.space)
                        )
                    ]
                )
            }
        }
    }
}

extension ShortcutsJumpSlot {
    /// The scroll viewport's coordinate space.
    static let space = "shortcutsJumpViewport"
}
