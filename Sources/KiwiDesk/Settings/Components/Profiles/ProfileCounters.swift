import KiwiDeskCore
import SwiftUI

/// Screen and Space counts leading a saved-profile row and a
/// preset card (#1624). The sentence is the tooltip; the counters
/// are hidden from VoiceOver, which reads it off the name instead.
struct ProfileCounters: View {
    let screens: Int
    let spaces: Int
    /// `ProfileCounters.sentence` for the same counts.
    let help: String

    /// Fits `display 9  squares 99` without clipping a longer count.
    static let columnWidth: CGFloat = 68

    var body: some View {
        HStack(spacing: 10) {
            count(screens, symbol: "display")
            count(spaces, symbol: "squares.below.rectangle")
        }
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(SettingsTheme.ink2)
        .fixedSize()
        .frame(minWidth: Self.columnWidth, alignment: .leading)
        .contentShape(Rectangle())
        .help(help)
        .accessibilityHidden(true)
    }

    private func count(_ value: Int, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).imageScale(.medium)
            Text(verbatim: "\(value)")
        }
    }

    /// "1 screen · 4 Spaces", with the override count third when a
    /// profile carries any.
    static func sentence(
        screens: Int,
        spaces: Int,
        overrides: Int = 0
    ) -> String {
        guard overrides > 0 else {
            return L(
                "profiles.summary.pair",
                "%1$@ · %2$@",
                screensPhrase(screens),
                spacesPhrase(spaces)
            )
        }
        return L(
            "profiles.summary.triple",
            "%1$@ · %2$@ · %3$@",
            screensPhrase(screens),
            spacesPhrase(spaces),
            overridesPhrase(overrides)
        )
    }

    private static func spacesPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.spaces.one", "1 Space")
            : L("profiles.spaces.many", "%1$d Spaces", count)
    }

    private static func overridesPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.overrides.one", "1 shortcut override")
            : L(
                "profiles.overrides.many",
                "%1$d shortcut overrides",
                count
            )
    }
}
