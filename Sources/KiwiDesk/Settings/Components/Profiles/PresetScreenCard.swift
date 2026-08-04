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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<layout.screenCount, id: \.self) {
                    screen in
                    outlineView(screen)
                }
            }
            Text(spaceCountText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var spaceCountText: String {
        layout.spaceCount == 1
            ? L("presets.spaces.one", "1 space")
            : L(
                "presets.spaces.many",
                "%1$d spaces",
                layout.spaceCount
            )
    }

    private func outlineView(_ screen: Int) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        Color(nsColor: .separatorColor)
                    )
            }
            .overlay {
                Image(systemName: glyph(screen))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(
                width: Self.outline.width,
                height: Self.outline.height
            )
            .help(screenHelp(screen))
    }

    /// Screen 0 is the main display, 1 the next secondary, … —
    /// `StandardLayout.spaceScreens`' own numbering, and the same
    /// one `ProfileComposition` composes with.
    private func spaces(on screen: Int) -> [SpaceID] {
        let all = (1...max(layout.spaceCount, 1)).map {
            SpaceID($0)
        }
        return all.filter {
            (layout.spaceScreens[$0] ?? 0) == screen
        }
    }

    private func firstMode(on screen: Int) -> LayoutMode {
        guard let first = spaces(on: screen).first else {
            return .bsp
        }
        return layout.spaceModes[first] ?? .bsp
    }

    private func glyph(_ screen: Int) -> String {
        firstMode(on: screen).glyph
    }

    /// Named for the reader who cannot see the glyph — the count
    /// of spaces on that screen and the layout it opens in.
    private func screenHelp(_ screen: Int) -> String {
        L(
            "presets.screen_help",
            "Screen %1$d: %2$d space(s), opens in %3$@",
            screen + 1,
            spaces(on: screen).count,
            firstMode(on: screen).displayName
        )
    }
}
