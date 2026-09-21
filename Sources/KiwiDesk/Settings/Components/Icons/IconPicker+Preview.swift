import KiwiDeskCore
import SwiftUI

/// The picker's browse tabs and the header that previews the
/// selection where it lands (`IconPicker`).
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

    /// Where the header previews the selection: the menu bar
    /// for a layer, the Space Bar's plate for a Space (#1485).
    enum IconPreview {
        case menuBar
        /// The draft's bar style and the Space the icon
        /// identifies — an empty icon then previews the
        /// identifier the bar falls back to, Core's own ladder.
        case spaceBar(SpaceBarStyle, space: SpaceID)
    }

    /// The selection at its destination — a light and a dark
    /// swatch side by side, since the destination is composited
    /// over the wallpaper and one extreme can pass while the
    /// other fails.
    @ViewBuilder var previewHeader: some View {
        switch preview {
        case .menuBar:
            HStack(spacing: 8) {
                menuBarSwatch(scheme: .light)
                menuBarSwatch(scheme: .dark)
                caption(
                    L(
                        "icon_picker.preview.menu_bar",
                        "Menu bar preview"
                    )
                )
                Spacer()
            }
        case .spaceBar(let style, let space):
            HStack(spacing: 8) {
                barPlateSwatch(style, space: space, scheme: .light)
                barPlateSwatch(style, space: space, scheme: .dark)
                caption(
                    L(
                        "icon_picker.preview.space_bar",
                        "Space Bar preview"
                    )
                )
                Spacer()
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    func menuBarSwatch(
        scheme: ColorScheme
    ) -> some View {
        swatch(scheme: scheme) {
            IconGlyphLabel(
                icon: icon,
                placeholder: "rectangle.3.group"
            )
            .font(.system(size: 15))
            .foregroundStyle(
                scheme == .light ? .black : .white
            )
        }
    }

    /// The Space Bar's plate — `fill_color` over a wallpaper —
    /// with the glyph the bar draws: a symbol takes `item_color`,
    /// an emoji no tint, the classification Core's, never the
    /// picker's own (#1485, #702).
    func barPlateSwatch(
        _ style: SpaceBarStyle,
        space: SpaceID,
        scheme: ColorScheme
    ) -> some View {
        swatch(scheme: scheme) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(kiwiHex: style.fillColor))
            BarPlateGlyph(
                glyph: KiwiCore.spaceIdentifier(
                    id: space,
                    icon: icon
                ),
                style: style
            )
        }
    }

    /// One wallpaper swatch: white or black IS the appearance it
    /// stands for, and both are always drawn.
    private func swatch(
        scheme: ColorScheme,
        @ViewBuilder content: () -> some View
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(scheme == .light ? Color.white : .black)
            .frame(width: 34, height: 26)
            .overlay { content() }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        Color.secondary.opacity(0.4)
                    )
            )
    }
}

/// A Space Bar identifier as the picker previews it, in the
/// bar's resting ink (#1485).
struct BarPlateGlyph: View {
    let glyph: SpaceGlyph
    let style: SpaceBarStyle

    /// What the bar's resting item paints a glyph with: a tinted
    /// one takes `item_color` at full strength, an untinted one
    /// (an emoji) keeps its own colours at the bar's dim — the
    /// bar's own `styleIdentifier` rule, so the preview cannot
    /// tint what the bar does not.
    static func ink(
        of glyph: SpaceGlyph,
        in style: SpaceBarStyle
    ) -> (hex: String?, opacity: CGFloat) {
        switch glyph {
        case .symbol, .text(_, tinted: true):
            return (style.itemColor, 1)
        case .text(_, tinted: false):
            return (nil, style.dimFactor)
        }
    }

    var body: some View {
        let ink = Self.ink(of: glyph, in: style)
        Group {
            switch glyph {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: 15))
            case .text(let text, _):
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(
            ink.hex.map { Color(kiwiHex: $0) } ?? .primary
        )
        .opacity(ink.opacity)
    }
}
