import KiwiDeskCore
import SwiftUI

/// A split screen's area names, under its card (#3697, ui-designer
/// 2026-11-27): each name centred under its own area's span, one
/// line per top edge, the way labels sit under icons in Finder. A
/// click selects the area as its pane does; VoiceOver hears the
/// name on the pane, so these are hidden from it.
struct ScreenAreaCaptions: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    let split: ScreenSplit
    let width: CGFloat
    @Binding var selection: ScreenSelection?

    var body: some View {
        let lines = ScreenArrangement.captionLines(of: split)
        VStack(
            alignment: .leading,
            spacing: ScreenArrangement.captionSpacing
        ) {
            ForEach(lines.indices, id: \.self) { index in
                ZStack(alignment: .topLeading) {
                    ForEach(lines[index], id: \.id) { entry in
                        name(entry)
                    }
                }
                .frame(
                    width: width,
                    height: ScreenArrangement.captionLine,
                    alignment: .topLeading
                )
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func name(
        _ entry: ScreenArrangement.Caption
    ) -> some View {
        let span = ScreenArrangement.paneRect(
            entry.rect,
            in: CGSize(width: width, height: 1)
        )
        if span.width >= ScreenArrangement.captionMinWidth {
            let mine = ScreenSelection(display: display.id, area: entry.id)
            let selected = selection == mine
            Text(model.areaLabel(entry.id, on: display) ?? "")
                .font(.caption2)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(
                    selected ? SettingsTheme.ink : SettingsTheme.ink2
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: span.width - 4)
                .contentShape(Rectangle())
                .onTapGesture { selection = selected ? nil : mine }
                .offset(x: span.minX + 2)
        }
    }
}
