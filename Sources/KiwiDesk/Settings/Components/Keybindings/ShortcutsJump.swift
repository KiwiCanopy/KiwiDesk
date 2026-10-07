import Foundation
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
    /// label, and its id both the card's scroll anchor and the key
    /// its card reports its frame under, so one key names all
    /// three.
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

    /// The census container the chip leads to.
    var container: SettingsContainer {
        switch self {
        case .gestures: return .gestures
        case .focus: return .focus
        case .moveWindows: return .moveWindows
        case .sizeFloat: return .sizeAndFloat
        case .openApplications: return .openApplications
        }
    }

    /// The chip a rule follows: everything after it is scoped to
    /// one layer, this card to none.
    var ruledAfter: Bool { self == .gestures }
}

/// The page's measured geometry, in the scroll viewport's space:
/// `minY` 0 is the bar's lower edge.
struct ShortcutsJumpPage: Equatable {
    /// Section cards by catalog anchor id.
    var sections: [String: CGRect] = [:]
    var content: CGRect?
    var viewport: CGRect?
}

/// A clicked chip, kept marked until the user scrolls: a group
/// near the end may never bring its header to the bar.
struct ShortcutsJumpHold: Equatable {
    let group: ShortcutsJumpGroup
    /// Geometry changing before this is the jump's own scroll.
    let until: Date

    init(_ group: ShortcutsJumpGroup, at now: Date) {
        self.group = group
        until = now.addingTimeInterval(
            SettingsReveal.scroll + SettingsReveal.settle + 0.2
        )
    }

    /// The hold a geometry change at `now` leaves standing.
    func surviving(at now: Date) -> ShortcutsJumpHold? {
        now <= until ? self : nil
    }
}

/// What the pinned bar reads off the page: which group is
/// current and whether content has slid under the bar.
struct ShortcutsJumpReading: Equatable {
    var marked: ShortcutsJumpGroup?
    var underlapped = false

    /// How far below the bar a header may sit and still count as
    /// the one under it — the slack a jump's landing may leave.
    static let reach: CGFloat = 24

    /// A held chip wins. Unscrolled, the first group is current,
    /// whatever sits above it; at the end of a scroll, the last.
    /// Otherwise it is the last group whose header has reached the
    /// bar while its card is still under it.
    @MainActor static func read(
        _ page: ShortcutsJumpPage,
        holding hold: ShortcutsJumpGroup? = nil
    ) -> ShortcutsJumpReading {
        var reading = ShortcutsJumpReading()
        reading.underlapped = (page.content?.minY ?? 0) < 0
        let drawn = ShortcutsJumpGroup.allCases.compactMap {
            group -> (ShortcutsJumpGroup, CGRect)? in
            page.sections[group.control.id].map { (group, $0) }
        }
        if let hold {
            reading.marked = hold
        } else if !reading.underlapped {
            reading.marked = drawn.first?.0
        } else if atEnd(page) {
            reading.marked = drawn.last?.0
        } else if let current = drawn.last(where: {
            $0.1.minY <= reach
        }), current.1.maxY > reach {
            reading.marked = current.0
        }
        return reading
    }

    /// Scrolled to the bottom of content taller than the viewport.
    private static func atEnd(_ page: ShortcutsJumpPage) -> Bool {
        guard let content = page.content, let viewport = page.viewport
        else { return false }
        return content.minY < 0 && content.maxY <= viewport.maxY + 1
    }
}

/// The page geometry and a held chip, kept off the view's state
/// so a scroll frame re-renders the bar only when its reading
/// changes.
@MainActor
final class ShortcutsJumpTracker {
    private var page = ShortcutsJumpPage()
    private var hold: ShortcutsJumpHold?

    func sections(
        _ frames: [String: CGRect],
        at now: Date = Date()
    ) -> ShortcutsJumpReading {
        page.sections = frames
        return moved(at: now)
    }

    func slots(
        _ frames: [ShortcutsJumpSlot: CGRect],
        at now: Date = Date()
    ) -> ShortcutsJumpReading {
        page.content = frames[.content]
        page.viewport = frames[.viewport]
        return moved(at: now)
    }

    func jump(
        to group: ShortcutsJumpGroup,
        at now: Date = Date()
    ) -> ShortcutsJumpReading {
        hold = ShortcutsJumpHold(group, at: now)
        return ShortcutsJumpReading.read(page, holding: group)
    }

    private func moved(at now: Date) -> ShortcutsJumpReading {
        hold = hold?.surviving(at: now)
        return ShortcutsJumpReading.read(page, holding: hold?.group)
    }
}

/// The page's own two measured places.
enum ShortcutsJumpSlot: Hashable, Sendable {
    case content
    case viewport
}

/// The measured content and viewport frames.
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
                            in: .named(SettingsSectionFrames.space)
                        )
                    ]
                )
            }
        }
    }
}
