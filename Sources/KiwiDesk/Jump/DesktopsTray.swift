import AppKit
import KiwiDeskCore
import SwiftUI

/// The footer's leading slot while windows ride along (#1229 ▸
/// Carrying): "Moving windows: 2" and their icons, in pick order.
struct DesktopsTray: View {
    let state: DesktopsState
    let icons: [pid_t: NSImage]

    var body: some View {
        HStack(spacing: 4) {
            Text(DesktopsText.moving(state.carried.count))
                .font(.caption.weight(.medium))
                .lineLimit(1)
            ForEach(state.carried.prefix(4), id: \.self) { id in
                if let window = state.overview.window(id) {
                    icon(window)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DesktopsText.moving(state.carried.count))
    }

    @ViewBuilder private func icon(
        _ window: DesktopOverview.Window
    ) -> some View {
        if let image = icons[window.pid] {
            Image(nsImage: image)
                .resizable()
                .frame(width: 16, height: 16)
        }
    }
}
