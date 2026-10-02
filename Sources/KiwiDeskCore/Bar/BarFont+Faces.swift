import AppKit
import CoreText

/// An installed family's faces and axes, read for `BarFont` and
/// kept per family until the font set changes.
extension BarFont {
    /// One upright face of a family: its weight, 100–900, and its
    /// `wght` axis on the 1–1000 scale when it has one.
    struct Face: Equatable {
        let postScriptName: String
        let weight: Int
        let axis: ClosedRange<Double>?

        func font(size: CGFloat) -> NSFont {
            NSFont(name: postScriptName, size: size)
                ?? .systemFont(ofSize: size)
        }
    }

    /// What `BarFont` has read, until the font set changes.
    struct Cache {
        var faces: [String: [Face]] = [:]
        var missing: Set<String> = []
        var families: [String]?
        var systemAxes: [Bool: ClosedRange<Double>] = [:]
    }

    static var cache = Cache()

    /// The OpenType `wght` variation axis tag.
    static let wghtAxis = 0x7767_6874

    /// Units apart within which two weights are one face — the one
    /// tolerance `rendering` (and so a chip and the caption) reads,
    /// so a font whose Medium reports 480 draws and offers Medium.
    static let faceTolerance = 50

    /// Whether a face of weight `drawn` counts as `asked`.
    static func sameWeight(_ drawn: Int, _ asked: Int) -> Bool {
        abs(drawn - asked) < faceTolerance
    }

    /// Forgets everything read about the installed fonts — the
    /// font-set observer's one call.
    public static func invalidate() {
        cache = Cache()
        generation += 1
    }

    /// Counts `invalidate` calls; a bar redraws when it moved
    /// (`BarDrawEnvironment`, #1901).
    private(set) static var generation = 0

    /// A family's upright, normal-width faces — every face where
    /// the family has none — or nil when it is not installed.
    static func faces(of family: String) -> [Face]? {
        if let faces = cache.faces[family] { return faces }
        if cache.missing.contains(family) { return nil }
        guard let faces = readFaces(of: family) else {
            cache.missing.insert(family)
            return nil
        }
        cache.faces[family] = faces
        return faces
    }

    private static func readFaces(of family: String) -> [Face]? {
        guard
            let members = NSFontManager.shared.availableMembers(
                ofFontFamily: family
            ), !members.isEmpty
        else { return nil }
        let slanted: UInt =
            NSFontTraitMask.italicFontMask.rawValue
            | NSFontTraitMask.condensedFontMask.rawValue
            | NSFontTraitMask.expandedFontMask.rawValue
            | NSFontTraitMask.narrowFontMask.rawValue
        var all: [Face] = []
        var upright: [Face] = []
        for member in members {
            guard let name = member.first as? String,
                let font = NSFont(name: name, size: 12)
            else { continue }
            let face = Face(
                postScriptName: name,
                weight: weight(of: font),
                axis: weightAxis(of: font)
            )
            all.append(face)
            let traits = (member.last as? NSNumber)?.uintValue ?? 0
            if traits & slanted == 0 { upright.append(face) }
        }
        let faces = upright.isEmpty ? all : upright
        return faces.isEmpty ? nil : faces
    }

    /// The system face's `wght` axis — SF Mono's starts near 295,
    /// so a lighter ask draws clamped and the caption says so.
    static func systemAxis(monospaced: Bool) -> ClosedRange<Double> {
        if let axis = cache.systemAxes[monospaced] { return axis }
        let font =
            monospaced
            ? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            : NSFont.systemFont(ofSize: 12)
        let axis = weightAxis(of: font) ?? 1...1000
        cache.systemAxes[monospaced] = axis
        return axis
    }

    /// The face nearest `weight`; a tie takes the lighter below
    /// 500 and the heavier from it, as CSS matching does.
    static func nearest(_ faces: [Face], to weight: Int) -> Face {
        faces.min { a, b in
            let da = abs(a.weight - weight)
            let db = abs(b.weight - weight)
            guard da == db else { return da < db }
            return weight < 500 ? a.weight < b.weight : a.weight > b.weight
        }!
    }

    /// `font`'s `wght` axis on the 1–1000 scale, or nil when it has
    /// none. A legacy axis normalized around 1 (Skia's 0.48–3.2)
    /// speaks no weight number, so it counts as none.
    static func weightAxis(of font: NSFont) -> ClosedRange<Double>? {
        let axes =
            CTFontCopyVariationAxes(font as CTFont) as? [[String: Any]]
        guard
            let axis = axes?.first(where: {
                ($0[kCTFontVariationAxisIdentifierKey as String]
                    as? NSNumber)?.intValue == wghtAxis
            }),
            let low =
                (axis[kCTFontVariationAxisMinimumValueKey as String]
                as? NSNumber)?.doubleValue,
            let high =
                (axis[kCTFontVariationAxisMaximumValueKey as String]
                as? NSNumber)?.doubleValue,
            high > 100, low < high
        else { return nil }
        return low...high
    }

    /// Core Text's weight trait (−1…1) on the 100–900 scale, read
    /// off `NSFont.Weight`'s nine named values.
    static func weight(of font: NSFont) -> Int {
        let traits = CTFontCopyTraits(font as CTFont) as? [String: Any]
        let trait =
            (traits?[kCTFontWeightTrait as String] as? NSNumber)?
            .doubleValue ?? 0
        let ladder = BarFontWeight.allCases.map {
            (Double($0.nsWeight.rawValue), Double($0.value))
        }
        guard let first = ladder.first, let last = ladder.last else {
            return BarFontWeight.regular.value
        }
        if trait <= first.0 { return Int(first.1) }
        if trait >= last.0 { return Int(last.1) }
        for (low, high) in zip(ladder, ladder.dropFirst())
        where trait <= high.0 {
            let share = (trait - low.0) / (high.0 - low.0)
            return Int((low.1 + share * (high.1 - low.1)).rounded())
        }
        return Int(last.1)
    }
}

extension BarFontWeight {
    /// The AppKit weight of the same name.
    var nsWeight: NSFont.Weight {
        switch self {
        case .ultralight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}
