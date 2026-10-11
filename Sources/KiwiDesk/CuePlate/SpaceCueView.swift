import KiwiDeskCore
import SwiftUI

/// The Space cue (#2143): #2142's plate naming the Space a switch
/// landed on — its identifier large, in the Desktop plate's digit
/// face for one or two characters and a title weight for a longer
/// name — with its layout's symbol where the Desktop plate has its
/// dots: dots mean a Desktop, a symbol means a Space.
struct SpaceCueView: View {
    let cue: SpaceSwitchCue

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
        .glassChrome(
            in: RoundedRectangle(
                cornerRadius: CuePlateModel.corner,
                style: .continuous
            ),
            // Plain system glass, as the Desktop plate (#2142).
            enabled: true,
            variant: .regular,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    @ViewBuilder private var identifier: some View {
        let name = cue.space.raw
        if name.count <= Self.digitLength {
            Text(verbatim: name)
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
        } else {
            Text(verbatim: name)
                .font(Self.titleFont)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Self.titleFit(name))
        }
    }

    static let titleNSFont = NSFont.systemFont(ofSize: 26, weight: .semibold)
    static var titleFont: Font { Font(titleNSFont) }

    /// The name's own width, capped at the caption width, so the
    /// plate widens with a long name only that far.
    static func titleFit(_ text: String) -> CGFloat {
        let width = (text as NSString)
            .size(withAttributes: [.font: titleNSFont]).width
        return min(ceil(width) + 1, CuePlateModel.captionWidth)
    }
}
