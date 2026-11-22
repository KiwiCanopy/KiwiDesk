import CoreGraphics
import Foundation
import KiwiDeskCore

/// An area's words (#3517 rulings 15, 27): its positional default
/// in the user's language, and the one " – " frame that names an
/// area beside its screen everywhere — the card, the Screen menu
/// and VoiceOver.
@MainActor
enum ScreenAreaWords {
    static func position(_ position: ScreenAreaPosition) -> String {
        switch position {
        case .left: L("monitors.split.left", "Left")
        case .middle: L("monitors.split.middle", "Middle")
        case .right: L("monitors.split.right", "Right")
        case .top: L("monitors.split.top", "Top")
        case .bottom: L("monitors.split.bottom", "Bottom")
        case .numbered(let n):
            L("monitors.split.numbered", "Area %1$d", n)
        }
    }

    /// "LG UltraWide – Left".
    static func composed(screen: String, area: String) -> String {
        L("monitors.split.name", "%1$@ – %2$@", screen, area)
    }

    /// The same frame unfilled, for a header that draws its two
    /// halves apart (`SentenceFrame`).
    static var nameFrame: String {
        L("monitors.split.name", "%1$@ – %2$@")
    }
}

/// A selection in the Screens picture: a screen, and on a split
/// screen one of its areas. Keyed by the `DisplayID`, since twins
/// share a fingerprint.
struct ScreenSelection: Hashable {
    let display: DisplayID
    let area: Int?
}

extension SettingsModel {
    /// `display`'s split in the draft, nil while it is whole.
    func areaSplit(of display: Display) -> ScreenSplit? {
        config.settings.displayAreas[display.fingerprint]
            .flatMap { $0.isWhole ? nil : $0 }
    }

    /// `display`'s split as the editor acts on it: the stored one,
    /// else the whole screen as one area 0.
    func editableSplit(of display: Display) -> ScreenSplit {
        config.settings.displayAreas[display.fingerprint]
            ?? ScreenSplit.whole(
                width: Int(display.frame.width),
                height: Int(display.frame.height)
            )
    }

    /// Area `id`'s own label: the user's name, else its position.
    /// Nil on a whole screen, which has no areas to name.
    func areaLabel(_ id: Int, on display: Display) -> String? {
        guard let split = areaSplit(of: display),
            let area = split.areas.first(where: { $0.id == id })
        else { return nil }
        if let name = area.name { return name }
        return split.positions[id].map(ScreenAreaWords.position)
    }

    /// The area's full name, "LG UltraWide – Left"; the screen's
    /// own name where it is whole or `id` is nil.
    func areaName(_ id: Int?, on display: Display) -> String {
        let screen = screenLabel(display)
        guard let id, let area = areaLabel(id, on: display) else {
            return screen
        }
        return ScreenAreaWords.composed(screen: screen, area: area)
    }

    /// The words for a stored Screen pin: a connected screen's, its
    /// area's where the key names one that exists; nil where no
    /// one connected screen carries the fingerprint.
    func pinWords(_ pin: String) -> String? {
        let key = ScreenAreaKey(parsing: pin)
        let found = displays.filter {
            $0.fingerprint == key.fingerprint
        }
        guard found.count == 1, let display = found.first else {
            return nil
        }
        return areaName(
            key.areaID == 0 ? areaZero(of: display) : key.areaID,
            on: display
        )
    }

    /// The area holding id 0 on a split screen, nil on a whole one.
    private func areaZero(of display: Display) -> Int? {
        areaSplit(of: display) == nil ? nil : 0
    }
}
