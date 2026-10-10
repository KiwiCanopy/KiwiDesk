import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// What the Desktop switch cue shows (#2142).
@MainActor
final class DesktopCueModel: ObservableObject {
    @Published var cue: DesktopSwitchCue?
    @Published var visible = false

    static let hold: TimeInterval = 0.6
    static let fade: TimeInterval = 0.25
    static let side: CGFloat = 128
    static let tallSide: CGFloat = 152
    static let corner: CGFloat = 28
    static let captionWidth: CGFloat = 208
    /// The panel's fixed room: the widest plate a caption makes,
    /// centred, so a cue never resizes the panel.
    static let room = CGSize(width: captionWidth + 32, height: tallSide)
    static let captionFont = NSFont.systemFont(ofSize: 13, weight: .medium)

    /// The caption's own width, capped: a bare `maxWidth` frame
    /// would stretch the plate to the cap for any name.
    static func captionFit(_ text: String) -> CGFloat {
        let width = (text as NSString)
            .size(withAttributes: [.font: captionFont]).width
        return min(ceil(width) + 1, captionWidth)
    }

    /// The spoken cue: "Desktop 2 of 4", "Desktop 4, 2 of 3" where
    /// the screen's own count starts past 1, and the profile a
    /// binding loaded after it.
    static func spoken(_ cue: DesktopSwitchCue) -> String {
        let desktop =
            cue.number == cue.position
            ? L(
                "desktop_cue.ax.same",
                "Desktop %1$d of %2$d",
                cue.number,
                cue.count
            )
            : L(
                "desktop_cue.ax",
                "Desktop %1$d, %2$d of %3$d",
                cue.number,
                cue.position,
                cue.count
            )
        guard let profile = cue.loadedProfile else { return desktop }
        return L(
            "desktop_cue.ax.profile",
            "%1$@, profile %2$@",
            desktop,
            profile
        )
    }
}

/// A centred plate: the Desktop's number, the profile a binding
/// loaded, and a dot per Desktop on the screen with the current
/// one filled and larger. No controls; the panel ignores the
/// mouse.
struct DesktopCueView: View {
    @ObservedObject var model: DesktopCueModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        plate
            .frame(
                width: DesktopCueModel.room.width,
                height: DesktopCueModel.room.height
            )
            .opacity(model.visible ? 1 : 0)
            .animation(
                // Appears at once; only the leave fades (#2142).
                reduceMotion || model.visible
                    ? nil : .easeOut(duration: DesktopCueModel.fade),
                value: model.visible
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var plate: some View {
        if let cue = model.cue {
            VStack(spacing: 0) {
                Text(verbatim: "\(cue.number)")
                    .font(
                        .system(size: 64, weight: .semibold, design: .rounded)
                    )
                    .monospacedDigit()
                if let profile = cue.loadedProfile {
                    Text(verbatim: profile)
                        .font(Font(DesktopCueModel.captionFont))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(
                            width: DesktopCueModel.captionFit(profile)
                        )
                        .padding(.top, 6)
                }
                dots(cue)
                    .padding(.top, 14)
            }
            .padding(.horizontal, 16)
            .frame(
                minWidth: DesktopCueModel.side,
                minHeight: height(cue),
                maxHeight: height(cue)
            )
            .glassChrome(
                in: RoundedRectangle(
                    cornerRadius: DesktopCueModel.corner,
                    style: .continuous
                ),
                // Plain system glass by ruling (#2142), never a
                // look's or a switch's; `.regular` carries the digit.
                enabled: true,
                variant: .regular,
                fallback: AnyShapeStyle(.regularMaterial)
            )
        }
    }

    private func height(_ cue: DesktopSwitchCue) -> CGFloat {
        cue.loadedProfile == nil
            ? DesktopCueModel.side : DesktopCueModel.tallSide
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
