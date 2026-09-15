import KiwiDeskCore
import SwiftUI

/// The picker's browse tabs and the header that previews the
/// selection at its destination size (`IconPicker`).
extension IconPicker {
    /// Browse tabs for curated symbol and emoji collections (#68
    /// §6.4). Symbols lead for every caller (#1379).
    enum IconTab: String, CaseIterable, Identifiable {
        case symbols = "Symbols"
        case emoji = "Emoji"
        var id: String { rawValue }

        /// The tab every open starts on.
        static let resting: IconTab = .symbols

        @MainActor var title: String {
            switch self {
            case .emoji: L("icon_picker.emoji", "Emoji")
            case .symbols: L("icon_picker.symbols", "Symbols")
            }
        }

        var choices: [IconChoice] {
            switch self {
            case .emoji: IconCatalog.emoji
            case .symbols: IconCatalog.symbols
            }
        }
    }

    enum IconPreview {
        case menuBar
        case chip
    }

    /// The selection at its destination size — for the menu
    /// bar, a light and a dark swatch side by side.
    @ViewBuilder var previewHeader: some View {
        switch preview {
        case .menuBar:
            HStack(spacing: 8) {
                menuBarSwatch(scheme: .light)
                menuBarSwatch(scheme: .dark)
                Text(
                    L(
                        "icon_picker.preview.menu_bar",
                        "Menu bar preview"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
        case .chip:
            HStack(spacing: 8) {
                IconGlyphLabel(icon: icon)
                    .font(.caption)
                Text(
                    L(
                        "icon_picker.preview.row",
                        "Row preview"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    func menuBarSwatch(
        scheme: ColorScheme
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(scheme == .light ? Color.white : .black)
            .frame(width: 34, height: 26)
            .overlay {
                IconGlyphLabel(
                    icon: icon,
                    placeholder: "rectangle.3.group"
                )
                .font(.system(size: 15))
                .foregroundStyle(
                    scheme == .light ? .black : .white
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        Color.secondary.opacity(0.4)
                    )
            )
    }
}
