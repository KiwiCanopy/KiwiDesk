import KiwiDeskCore
import SwiftUI

/// A preset's thumbnail (#678 turn 13a): **one outline per
/// screen**, not one tile per space.
///
/// The old thumbnail drew a tile per space, which reads at four
/// and turns into a row of identical stamps at ten — and a
/// three-screen preset's whole point is *which screen gets what*,
/// which a flat run of tiles cannot say at any count. Screens are
/// the thing that stays legible from one screen to three, so the
/// picture draws screens and the count of spaces goes underneath
/// as text.
///
/// Each outline carries the glyph of its screen's FIRST space —
/// the layout that screen opens on. That is a deliberate part of
/// the preset's plan rather than a sample: `spaceScreens` orders
/// the spaces per screen, and the first one is what a user lands
/// in when the preset applies.
struct PresetScreenCard: View {
    let layout: StandardLayout

    private static let outline = CGSize(width: 34, height: 22)

    /// Clamped at zero: a hand-edited layout claiming a negative
    /// screen count must not trap on the range.
    private var screens: Range<Int> {
        0..<max(layout.screenCount, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(screens, id: \.self) { screen in
                    outlineView(screen)
                }
            }
            Text(spaceCountText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// One noun, one pair of keys: the profile row counts spaces
    /// with `profiles.spaces.*` and so does this card. A second
    /// pair with byte-identical English doubles the translation
    /// work and lets the two drift per locale with nothing to
    /// catch it.
    private var spaceCountText: String {
        spaceCountPhrase(layout.spaceCount)
    }

    private func spaceCountPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.spaces.one", "1 space")
            : L("profiles.spaces.many", "%1$d spaces", count)
    }

    /// An empty screen draws its outline with NO glyph: a layout
    /// mode drawn on a screen the preset plans nothing for is a
    /// claim about behavior that applying it would not produce.
    private func outlineView(_ screen: Int) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(SettingsTheme.accent.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        SettingsTheme.hairline
                    )
            }
            .overlay {
                if let mode = openingMode(screen) {
                    Image(systemName: mode.glyph)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(
                width: Self.outline.width,
                height: Self.outline.height
            )
            .help(screenHelp(screen))
    }

    /// Screen 0 is the main display, 1 the next secondary, … —
    /// and both the plan and its sparse fallbacks are the
    /// LAYOUT's to answer (`StandardLayout+Screens`), the same
    /// accessors `ProfileComposition.compose` builds a real
    /// profile from. `screens:` is the preset's own screen count,
    /// which is what this card draws: the composer clamps into
    /// the LIVE display list instead, so the two agree exactly
    /// when the preset is appliable — the state its Apply button
    /// requires.
    private func spaces(on screen: Int) -> [SpaceID] {
        layout.spaces(
            onScreen: screen,
            screens: layout.screenCount
        )
    }

    private func openingMode(_ screen: Int) -> LayoutMode? {
        layout.openingMode(
            onScreen: screen,
            screens: layout.screenCount
        )
    }

    /// Named for the reader who cannot see the glyph — the count
    /// of spaces on that screen and the layout it opens in. A
    /// screen the preset plans nothing for says so instead of
    /// naming a mode it does not have.
    private func screenHelp(_ screen: Int) -> String {
        guard let mode = openingMode(screen) else {
            return L(
                "presets.screen_help.empty",
                "Screen %1$d: no spaces",
                screen + 1
            )
        }
        // The count phrase, not a `space(s)` parenthetical: the
        // pair already exists for this noun, and the file uses
        // it fourteen lines up.
        return L(
            "presets.screen_help",
            "Screen %1$d: %2$@, opens in %3$@",
            screen + 1,
            spaceCountPhrase(spaces(on: screen).count),
            mode.displayName
        )
    }
}
