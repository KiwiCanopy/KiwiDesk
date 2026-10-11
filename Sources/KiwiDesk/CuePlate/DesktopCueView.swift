import KiwiDeskCore
import SwiftUI

/// A centred plate: the Desktop's number, the profile a binding
/// loaded, and a dot per Desktop on the screen with the current
/// one filled and larger. No controls; the panel ignores the
/// mouse.
struct DesktopCueView: View {
    let cue: DesktopSwitchCue

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "\(cue.number)")
                .font(CuePlateModel.digitFont)
                .monospacedDigit()
            if let profile = cue.loadedProfile {
                Text(verbatim: profile)
                    .font(Font(CuePlateModel.captionFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(
                        width: CuePlateModel.captionFit(profile)
                    )
                    .padding(.top, 6)
            }
            dots(cue)
                .padding(.top, 14)
        }
        .padding(.horizontal, 16)
        .frame(
            minWidth: height(cue),
            minHeight: height(cue),
            maxHeight: height(cue)
        )
        .glassChrome(
            in: RoundedRectangle(
                cornerRadius: CuePlateModel.corner,
                style: .continuous
            ),
            // Plain system glass by ruling (#2142), never a
            // look's or a switch's; `.regular` carries the digit.
            enabled: true,
            variant: .regular,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    /// The plate's side: square either way, a long profile name
    /// widening it past the side.
    private func height(_ cue: DesktopSwitchCue) -> CGFloat {
        cue.loadedProfile == nil
            ? CuePlateModel.side : CuePlateModel.tallSide
    }

    /// Shape carries the current Desktop, never colour.
    private func dots(_ cue: DesktopSwitchCue) -> some View {
        HStack(spacing: 3) {
            ForEach(1...max(cue.count, 1), id: \.self) { index in
                if index == cue.position {
                    Circle().fill(.primary).frame(width: 8, height: 8)
                } else {
                    Circle()
                        .strokeBorder(.primary, lineWidth: 1.25)
                        .frame(width: 6, height: 6)
                        .opacity(0.55)
                }
            }
        }
    }
}
