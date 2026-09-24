import CoreGraphics
import Foundation

/// Parsed `kiwishelf.set_*` setting (#1517). Speaks the bars' one
/// vocabulary and error type (`AppBarSettingError`), so a shared
/// field's message reads the same as a per-bar one.
enum KiwiShelfCommandSetting {
    case edge(AppBarEdge)
    case alignment(KiwiShelf.Alignment)
    case order(KiwiShelf.Order)
    case share(CGFloat)
    case thickness(CGFloat)
    case outerMargin(CGFloat)
    case innerMargin(CGFloat)
    case backgroundStyle(KiwiShelf.BackgroundStyle)
    case liquidGlass(Bool)
    case backgroundFit(KiwiShelf.BackgroundFit)
    case cornerRoundness(CGFloat)
    case itemGap(CGFloat)
    case fontSize(CGFloat)

    /// Parses a setter's field (the verb minus `set_`) and args.
    static func parse(
        field: String,
        args: [JSONValue]
    ) -> Result<KiwiShelfCommandSetting, AppBarSettingError> {
        if let setting = parseChoice(field: field, args: args) {
            return setting
        }
        if let keyword = numberFields[field] {
            guard let value = args.first?.numberValue,
                value.isFinite
            else { return .failure("expected a length (pt)") }
            return .success(keyword(max(0, value)))
        }
        return .failure("unknown kiwishelf setting: \(field)")
    }

    private static func parseChoice(
        field: String,
        args: [JSONValue]
    ) -> Result<KiwiShelfCommandSetting, AppBarSettingError>? {
        switch field {
        case "edge":
            return BarSettingChoice.value(args, AppBarEdge.self)
                .map(Self.edge)
        case "alignment":
            return BarSettingChoice.value(
                args,
                KiwiShelf.Alignment.self
            ).map(Self.alignment)
        case "order":
            return BarSettingChoice.value(args, KiwiShelf.Order.self)
                .map(Self.order)
        case "share":
            guard let value = args.first?.numberValue,
                value.isFinite
            else { return .failure("expected a percentage") }
            return .success(.share(value))
        case "background_style":
            return BarSettingChoice.value(
                args,
                KiwiShelf.BackgroundStyle.self
            ).map(Self.backgroundStyle)
        case "background_fit":
            return BarSettingChoice.value(
                args,
                KiwiShelf.BackgroundFit.self
            ).map(Self.backgroundFit)
        case "liquid_glass":
            guard let flag = args.first?.boolValue else {
                return .failure("expected boolean")
            }
            return .success(.liquidGlass(flag))
        default:
            return nil
        }
    }

    private static var numberFields:
        [String: (CGFloat) -> KiwiShelfCommandSetting]
    {
        [
            "thickness": Self.thickness,
            "outer_margin": Self.outerMargin,
            "inner_margin": Self.innerMargin,
            "corner_roundness": Self.cornerRoundness,
            "item_gap": Self.itemGap,
            "font_size": Self.fontSize,
        ]
    }

    /// Writes the value into the shelf, clamped where the shelf
    /// has a floor or a range.
    func apply(to shelf: inout KiwiShelf) {
        switch self {
        case .edge(let value): shelf.edge = value
        case .alignment(let value): shelf.alignment = value
        case .order(let value): shelf.order = value
        case .share(let value):
            shelf.share = min(
                max(value, KiwiShelf.shareRange.lowerBound),
                KiwiShelf.shareRange.upperBound
            )
        case .thickness(let value):
            shelf.thickness = max(KiwiShelf.minThickness, value)
        case .outerMargin(let value):
            shelf.outerMargin = max(KiwiShelf.minMargin, value)
        case .innerMargin(let value):
            shelf.innerMargin = max(KiwiShelf.minMargin, value)
        case .backgroundStyle(let value): shelf.backgroundStyle = value
        case .liquidGlass(let value): shelf.liquidGlass = value
        case .backgroundFit(let value): shelf.backgroundFit = value
        case .cornerRoundness(let value): shelf.cornerRoundness = value
        case .itemGap(let value): shelf.itemGap = value
        case .fontSize(let value): shelf.fontSize = value
        }
    }
}
