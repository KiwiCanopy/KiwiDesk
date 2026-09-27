import AppKit
import CoreText

/// The one home that turns the shelf's font family and weight into
/// an `NSFont` (#1681). Every bar text site and the Settings
/// preview ask it; the App Font and app icons never do.
///
/// The weight resolves HERE, at render time, never on write: a
/// variable family draws the exact value on its `wght` axis, one
/// without draws its nearest installed face, and a family that is
/// not installed draws System. `NSFont.systemFont(ofSize:weight:)`
/// is taken only at a named weight — it snaps an in-between one
/// (measured 2026-09-26, the issue carries the numbers). What a
/// family has is read once per family and kept until the font set
/// changes (`invalidate()`, called by the core's one observer).
@MainActor
public enum BarFont {
    /// What a family draws for an asked weight.
    public enum Rendering: Sendable, Equatable {
        /// The asked weight, within `sameWeight`.
        case exact
        /// No face or axis reaches the asked weight: this weight,
        /// the nearest the family has, draws instead.
        case nearestFace(weight: Int)
        /// The family is not installed: System draws.
        case missing
    }

    /// The bar text font for a family, a weight and a size.
    /// `tabularDigits` gives every digit one advance, for a count —
    /// except in the system pair, whose counts keep today's glyphs.
    public static func font(
        family: String,
        weight: Int,
        size: CGFloat,
        tabularDigits: Bool = false
    ) -> NSFont {
        let weight = KiwiShelf.clampFontWeight(Double(weight))
        switch family {
        case KiwiShelf.systemFontFamily:
            return systemFace(monospaced: false, weight: weight, size: size)
        case KiwiShelf.systemMonospacedFontFamily:
            return systemFace(monospaced: true, weight: weight, size: size)
        default:
            guard let faces = faces(of: family) else {
                return systemFace(
                    monospaced: false,
                    weight: weight,
                    size: size
                )
            }
            let face = nearest(faces, to: weight)
            var font = face.font(size: size)
            if let axis = face.axis {
                font = varied(font, weight: axis.clamp(weight), size: size)
            }
            return tabularDigits ? tabular(font, size: size) : font
        }
    }

    /// Whether `family` draws as itself rather than as System.
    public static func isInstalled(_ family: String) -> Bool {
        KiwiShelf.systemFontFamilies.contains(family)
            || faces(of: family) != nil
    }

    /// What `family` draws for `weight` — the caption's, the
    /// chips' and the Config Issue's one reading.
    public static func rendering(
        family: String,
        weight: Int
    ) -> Rendering {
        let drawn: Int
        switch family {
        case KiwiShelf.systemFontFamily:
            drawn = systemAxis(monospaced: false).clamp(weight)
        case KiwiShelf.systemMonospacedFontFamily:
            drawn = systemAxis(monospaced: true).clamp(weight)
        default:
            guard let faces = faces(of: family) else { return .missing }
            let face = nearest(faces, to: weight)
            drawn = face.axis?.clamp(weight) ?? face.weight
        }
        return sameWeight(drawn, weight)
            ? .exact : .nearestFace(weight: drawn)
    }

    /// Whether `family` has `weight` of its own — a named chip's
    /// enablement: exactly when `rendering` says it draws it.
    public static func offers(weight: Int, family: String) -> Bool {
        rendering(family: family, weight: weight) == .exact
    }

    /// Every installed family, A–Z, the two system families
    /// excluded (a picker pins them first).
    public static var installedFamilies: [String] {
        if let cached = cache.families { return cached }
        let families = NSFontManager.shared.availableFontFamilies
            .filter {
                !$0.hasPrefix(".")
                    && !KiwiShelf.systemFontFamilies.contains($0)
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        cache.families = families
        return families
    }

    /// Whether `family` can name itself in its own face — false for
    /// a symbol font (Core Text's symbolic class, which Webdings
    /// and Bodoni Ornaments carry although they map letters), and
    /// for one missing a letter of its name. A picker names such a
    /// family in the system face.
    public static func drawsOwnName(_ family: String) -> Bool {
        if KiwiShelf.systemFontFamilies.contains(family) { return true }
        guard isInstalled(family) else { return false }
        let font = font(family: family, weight: 400, size: 13) as CTFont
        let traits = CTFontGetSymbolicTraits(font).rawValue
        let classMask = CTFontSymbolicTraits.traitClassMask.rawValue
        let symbolic = CTFontStylisticClass.classSymbolic.rawValue
        guard traits & classMask != symbolic else { return false }
        let units = Array(family.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return CTFontGetGlyphsForCharacters(
            font,
            units,
            &glyphs,
            units.count
        ) && !glyphs.contains(0)
    }

    /// A system face: at a named weight inside its axis the
    /// system's own call — today's look at 400 — and the `wght`
    /// axis, clamped, anywhere else.
    private static func systemFace(
        monospaced: Bool,
        weight: Int,
        size: CGFloat
    ) -> NSFont {
        if !monospaced, weight == BarFontWeight.regular.value {
            return .systemFont(ofSize: size)
        }
        let named = BarFontWeight.nearest(to: weight)
        let face =
            monospaced
            ? NSFont.monospacedSystemFont(
                ofSize: size,
                weight: named.nsWeight
            )
            : NSFont.systemFont(ofSize: size, weight: named.nsWeight)
        let axis = systemAxis(monospaced: monospaced)
        guard named.value != weight || !axis.contains(Double(weight))
        else { return face }
        return varied(face, weight: axis.clamp(weight), size: size)
    }

    /// `font` with its `wght` axis set to `weight`.
    private static func varied(
        _ font: NSFont,
        weight: Int,
        size: CGFloat
    ) -> NSFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            NSFontDescriptor.AttributeName(
                rawValue: kCTFontVariationAttribute as String
            ): [wghtAxis: weight]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? font
    }

    /// `font` with every digit on one advance.
    private static func tabular(_ font: NSFont, size: CGFloat) -> NSFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            .featureSettings: [
                [
                    NSFontDescriptor.FeatureKey.typeIdentifier:
                        kNumberSpacingType,
                    NSFontDescriptor.FeatureKey.selectorIdentifier:
                        kMonospacedNumbersSelector,
                ]
            ]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? font
    }
}

extension ClosedRange where Bound == Double {
    /// `weight` held inside the axis, rounded to a whole weight.
    func clamp(_ weight: Int) -> Int {
        let held = Swift.min(
            Swift.max(Double(weight), lowerBound),
            upperBound
        )
        return Int(held.rounded())
    }
}
