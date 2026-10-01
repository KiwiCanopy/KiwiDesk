import KiwiDeskCore
import SwiftUI

/// The KiwiShelf font weight row (#1681), the split ratio's shape
/// (`SliderPresetRow`): a slider over `KiwiShelf.fontWeightRange`
/// with its readout, and the five common weights as chips beneath,
/// each drawn in its weight and greyed where the family has no
/// such face. A family of fixed faces greys the slider, which
/// then shows the face drawn (#1859). The caption says when the
/// family draws a face other than the stored weight.
struct FontWeightRow: View {
    @Binding var weight: Int
    let family: String

    private var label: String { L("kiwishelf.font_weight", "Font weight") }

    var body: some View {
        SliderPresetRow(
            label: label,
            help: L(
                "kiwishelf.font_weight.help",
                "How heavy both bars' text draws. A font "
                    + "without this weight draws its nearest "
                    + "one; the setting is kept for the next "
                    + "font."
            ),
            value: slider,
            range: Self.range,
            step: 10,
            readout: String(shown),
            spokenValue: BarFontText.spokenWeight(shown),
            sliderInert: fixedFaces
        ) {
            FontWeightChips(weight: $weight, family: family, label: label)
            if let fixedFaces {
                Text(fixedFaces)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The slider's band: Core's range, both edges.
    static let range: ClosedRange<Double> =
        Double(
            KiwiShelf.fontWeightRange.lowerBound
        )...Double(
            KiwiShelf.fontWeightRange.upperBound
        )

    /// The slider's position: the stored weight, or on a family
    /// of fixed faces the face it draws.
    static func shownWeight(family: String, weight: Int) -> Int {
        BarFont.hasWeightAxis(family)
            ? weight : BarFont.drawnWeight(family: family, weight: weight)
    }

    private var shown: Int {
        Self.shownWeight(family: family, weight: weight)
    }

    /// Why the slider is greyed: the family has fixed faces only.
    private var fixedFaces: String? {
        BarFontText.fixedFacesCaption(family: family)
    }

    private var slider: Binding<Double> {
        Binding(
            get: { Double(shown) },
            set: { weight = KiwiShelf.clampFontWeight($0) }
        )
    }

    private var caption: String? {
        BarFontText.weightCaption(
            family: family,
            rendering: BarFont.rendering(family: family, weight: weight),
            weight: weight
        )
    }
}

/// The five weight chips: a chip snaps the slider to its weight.
/// They wrap, since a word chip is wider than a fraction.
struct FontWeightChips: View {
    @Binding var weight: Int
    let family: String
    let label: String

    var body: some View {
        FlowLayout(spacing: ChipMetrics.spacing) {
            ForEach(BarFontWeight.chips, id: \.self) { named in
                PresetChip(
                    title: BarFontText.weightName(named),
                    font: .callout.weight(named.swiftUIWeight),
                    selected: weight == named.value
                ) {
                    weight = named.value
                }
                .modifier(lacking(named))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("ratio.chips", "%1$@ presets", label))
    }

    /// Greys a chip whose weight the family has no face for,
    /// saying so.
    private func lacking(_ named: BarFontWeight) -> GreyOut {
        let offered = BarFont.offers(weight: named.value, family: family)
        return GreyOut(
            active: !offered,
            help: offered
                ? ""
                : L(
                    "kiwishelf.font_weight.chip_missing",
                    "%1$@ has no “%2$@” face.",
                    BarFontText.familyName(family),
                    BarFontText.weightName(named)
                )
        )
    }
}

extension BarFontWeight {
    /// The SwiftUI weight of the same name, for a chip's title.
    var swiftUIWeight: Font.Weight {
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
