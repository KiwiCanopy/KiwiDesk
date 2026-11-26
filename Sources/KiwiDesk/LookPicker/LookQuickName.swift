import AppKit
import KiwiDeskCore

/// The quick name ⌘S gives the worn look in the picker (#3038, owner
/// ruling Q5): a fruit picked from the look's focus colour, then the
/// date — "Kiwi · Nov 24". Renamable at once.
enum LookFruit: CaseIterable, Equatable {
    case cherry, orange, mango, lemon, kiwi, blueberry, grape, plum
    case raspberry, coconut, blackberry

    /// The fruit for `hex`: a grey by its lightness, else by hue.
    static func of(hex: String) -> LookFruit {
        guard let rgba = HexColor.parse(hex),
            let color = NSColor(
                srgbRed: rgba.red,
                green: rgba.green,
                blue: rgba.blue,
                alpha: 1
            ).usingColorSpace(.sRGB)
        else { return .kiwi }
        return of(
            hue: Double(color.hueComponent) * 360,
            saturation: Double(color.saturationComponent),
            luminance: ColorVision.luminance(hex) ?? 0
        )
    }

    /// The fruit for a hue in degrees; a colour under
    /// `neutralSaturation` is a grey, light or dark.
    static func of(
        hue: Double,
        saturation: Double,
        luminance: Double
    ) -> LookFruit {
        if saturation < neutralSaturation {
            return luminance > 0.5 ? .coconut : .blackberry
        }
        let degrees = hue.truncatingRemainder(dividingBy: 360)
        return hueBands.first { degrees < $0.upTo }?.fruit ?? .cherry
    }

    static let neutralSaturation = 0.15

    /// Each band's upper hue; Kiwi's band is wide, so the default
    /// green names a kiwi.
    static let hueBands: [(upTo: Double, fruit: LookFruit)] = [
        (15, .cherry), (38, .orange), (52, .mango), (70, .lemon),
        (165, .kiwi), (255, .blueberry), (290, .grape), (320, .plum),
        (345, .raspberry), (360, .cherry),
    ]

    @MainActor var name: String {
        switch self {
        case .cherry: L("look_picker.fruit.cherry", "Cherry")
        case .orange: L("look_picker.fruit.orange", "Orange")
        case .mango: L("look_picker.fruit.mango", "Mango")
        case .lemon: L("look_picker.fruit.lemon", "Lemon")
        case .kiwi: L("look_picker.fruit.kiwi", "Kiwi")
        case .blueberry: L("look_picker.fruit.blueberry", "Blueberry")
        case .grape: L("look_picker.fruit.grape", "Grape")
        case .plum: L("look_picker.fruit.plum", "Plum")
        case .raspberry: L("look_picker.fruit.raspberry", "Raspberry")
        case .coconut: L("look_picker.fruit.coconut", "Coconut")
        case .blackberry: L("look_picker.fruit.blackberry", "Blackberry")
        }
    }
}

enum LookQuickName {
    /// "‹fruit› · ‹month day›" for a look whose focus colour is
    /// `hex`, on `date`, in the UI language.
    @MainActor static func name(focusHex hex: String, on date: Date) -> String
    {
        L(
            "look_picker.quick_name",
            "%1$@ · %2$@",
            LookFruit.of(hex: hex).name,
            monthDay(date)
        )
    }

    /// The month and day, as the UI language writes them.
    @MainActor static func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        // The language KiwiDesk speaks, not the system's.
        if let code = LocalizationManager.shared.effectiveLocale {
            formatter.locale = Locale(identifier: code)
        }
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }
}
