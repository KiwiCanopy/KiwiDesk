import KiwiDeskCore
import SwiftUI

/// The bars step's three choices (#2515), drawn in the looks
/// row's tile chrome: a name, a one-line caption and a still
/// picture of a screen's top edge — a full bar, a row of dots, or
/// nothing. No reveal plays here (gui.md ▸ a schematic draws one
/// frame).
struct OnboardingBarsTiles: View {
    /// The visibility every bar shares; nil marks no tile.
    let selected: ShelfVisibility?
    let pick: (ShelfVisibility) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(ShelfVisibility.allCases, id: \.self) { visibility in
                tile(visibility)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L("onboarding.bars.title", "Choose when the bars show")
        )
    }

    private func tile(_ visibility: ShelfVisibility) -> some View {
        let applied = visibility == selected
        return Button {
            pick(visibility)
        } label: {
            PaletteTile(
                name: Self.name(visibility),
                caption: Self.caption(visibility),
                isApplied: applied,
                captionLines: 3
            ) {
                OnboardingBarsPicture(visibility: visibility)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
    }

    /// Settings' own option names, so the tour and the Show row
    /// say one word.
    static func name(_ visibility: ShelfVisibility) -> String {
        AppBarOptions.visibility.first { $0.0 == visibility }?.1
            ?? ""
    }

    static func caption(_ visibility: ShelfVisibility) -> String {
        switch visibility {
        case .always:
            L(
                "onboarding.bars.always",
                "Always on screen. Your windows fit beside them."
            )
        case .auto:
            L(
                "onboarding.bars.auto",
                "Hidden to a thin mark. Rest the pointer on it to "
                    + "show the bar."
            )
        case .hidden:
            L(
                "onboarding.bars.hidden",
                "Nothing on screen. Show a bar with its shortcut "
                    + "below."
            )
        }
    }
}

/// A still screen for one visibility: two windows under the top
/// edge, and above them the bar, its dots, or nothing.
struct OnboardingBarsPicture: View {
    let visibility: ShelfVisibility

    private let inset: CGFloat = 6
    private let barHeight: CGFloat = 9
    private let dot: CGFloat = 4

    var body: some View {
        VStack(spacing: 4) {
            edge
            HStack(spacing: 4) {
                window
                window
            }
        }
        .padding(inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PaletteSceneThumbnail.plateRadius)
                .fill(SettingsTheme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PaletteSceneThumbnail.plateRadius)
                .stroke(SettingsTheme.hairline, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    /// What the top edge draws; `always` alone takes room from
    /// the windows, as the layout reserves only for it.
    @ViewBuilder private var edge: some View {
        switch visibility {
        case .always:
            Capsule()
                .fill(SettingsTheme.ink3)
                .frame(height: barHeight)
        case .auto:
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(SettingsTheme.ink3)
                        .frame(width: index == 0 ? dot * 2.5 : dot)
                }
            }
            .frame(height: dot)
        case .hidden:
            EmptyView()
        }
    }

    private var window: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(SettingsTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(SettingsTheme.hairline, lineWidth: 1)
            )
    }
}
