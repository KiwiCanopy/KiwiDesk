import KiwiDeskCore
import SwiftUI

/// The Space cue (#2143): #2142's plate naming the Space a switch
/// landed on — its identifier large, in the Desktop plate's digit
/// face for one or two characters and a title weight for a longer
/// name — with its layout's symbol where the Desktop plate has its
/// dots: dots mean a Desktop, a symbol means a Space.
struct SpaceCueView: View {
    let cue: SpaceSwitchCue
    /// KiwiHub's glass, the Fill with it under the toggle (#2569).
    let glass: PanelGlass

    /// Up to this many characters draw in the digit face.
    static let digitLength = 2

    var body: some View {
        VStack(spacing: 0) {
            identifier
            Image(systemName: cue.mode.symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .frame(
            minWidth: CuePlateModel.side,
            minHeight: CuePlateModel.side,
            maxHeight: CuePlateModel.side
        )
        .panelGlassChrome(
            in: RoundedRectangle(
                cornerRadius: CuePlateModel.corner,
                style: .continuous
            ),
            glass: glass,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    @ViewBuilder private var identifier: some View {
        let name = cue.space.raw
        if name.count <= Self.digitLength {
            Text(verbatim: name)
                .font(CuePlateModel.digitFont)
                .monospacedDigit()
        } else {
            Text(verbatim: name)
                .font(Self.titleFont)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(
                    width: CuePlateModel.captionFit(
                        name,
                        font: Self.titleNSFont
                    )
                )
        }
    }

    static let titleNSFont = NSFont.systemFont(ofSize: 26, weight: .semibold)
    static var titleFont: Font { Font(titleNSFont) }
}
