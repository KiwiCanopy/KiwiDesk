import Combine
import SwiftUI

/// What the slow-boot notice shows (#1715).
@MainActor
final class BootNoticeModel: ObservableObject {
    /// The `BootCountText` line, kept at its last value once boot
    /// is ready so the minimum hold still says something true.
    @Published var line = ""
    @Published var visible = false
    /// Fixed when the notice appears, so the digits never jitter.
    @Published var width: CGFloat = 0
    var liquidGlass = true

    static let fade: TimeInterval = 0.2
    static let height: CGFloat = 26
    static let textSize: CGFloat = 11.5
    static let glyphSize: CGFloat = 12
    static let spacing: CGFloat = 4
    static let leading: CGFloat = 8
    static let trailing: CGFloat = 12
    /// Everything but the text, for the fixed width.
    static let chrome = leading + glyphSize + spacing + trailing
}

/// One line on a capsule: KiwiDesk's menu-bar glyph, then the boot
/// count. No controls; the panel ignores the mouse.
struct BootNoticeView: View {
    @ObservedObject var model: BootNoticeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        capsule
            .opacity(model.visible ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: BootNoticeModel.fade),
                value: model.visible
            )
    }

    private var capsule: some View {
        HStack(spacing: BootNoticeModel.spacing) {
            glyph
            Text(model.line)
                .font(.system(size: BootNoticeModel.textSize, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, BootNoticeModel.leading)
        .padding(.trailing, BootNoticeModel.trailing)
        .frame(
            width: model.width,
            height: BootNoticeModel.height,
            alignment: .leading
        )
        .glassChrome(
            in: Capsule(),
            // `.regular` carries text, as the ⌃⌥K panel does.
            enabled: model.liquidGlass,
            variant: .regular,
            fallback: AnyShapeStyle(.regularMaterial)
        )
    }

    @ViewBuilder private var glyph: some View {
        if let icon = BrandAssets.menuBarIcon {
            Image(nsImage: icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: BootNoticeModel.glyphSize,
                    height: BootNoticeModel.glyphSize
                )
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
        }
    }
}
