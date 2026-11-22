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
    /// `display`'s split in the draft as Core would lay it out
    /// (`ScreenSplit.effective`), nil while it is whole.
    func areaSplit(of display: Display) -> ScreenSplit? {
        ScreenSplit.effective(
            config.settings.displayAreas[display.fingerprint],
            for: display
        )
    }

    /// Every connected screen's split in effect, by fingerprint —
    /// what the picture lays its panes and scale floor out from.
    var effectiveSplits: [String: ScreenSplit] {
        var splits: [String: ScreenSplit] = [:]
        for display in displays {
            splits[display.fingerprint] = areaSplit(of: display)
        }
        return splits
    }

    /// `display`'s split as the editor acts on it: the split in
    /// effect, else the whole screen as one area 0, keeping the
    /// stored next id (ruling 21).
    func editableSplit(of display: Display) -> ScreenSplit {
        let stored = config.settings.displayAreas[display.fingerprint]
        return areaSplit(of: display)
            ?? ScreenSplit.whole(of: display, after: stored)
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

    /// Every connected screen's area keys — a whole screen's bare
    /// fingerprint — in screen order, once each: twins share a
    /// fingerprint and so their keys (#3496).
    var areaKeys: [String] {
        var seen = Set<String>()
        return displays.flatMap { display in
            ScreensFamilyRows.areas(
                of: display,
                in: config.settings.displayAreas
            ).map(\.key)
        }
        .filter { seen.insert($0).inserted }
    }

    /// A stored pin as the picture places it: on a connected screen,
    /// the area it names while the split holds it, else area 0
    /// (ruling 22, `ScreenSplit.landing`); a disconnected pin as is.
    func resolvedPin(_ pin: String) -> String {
        let key = ScreenAreaKey(parsing: pin)
        guard
            let display = displays.first(where: {
                $0.fingerprint == key.fingerprint
            })
        else { return pin }
        return ScreenAreaKey(
            fingerprint: key.fingerprint,
            areaID: areaSplit(of: display)?.landing(key) ?? 0
        ).description
    }

    /// The words for a stored Screen pin: a connected screen's, its
    /// area's where the key names one that exists; nil where no
    /// one connected screen carries the fingerprint.
    func pinWords(_ pin: String) -> String? {
        let key = ScreenAreaKey(parsing: resolvedPin(pin))
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
