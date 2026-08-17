import KiwiDeskCore
import SwiftUI

/// General ▸ About: the brand block, the version string and
/// the support link. Split out of `GeneralSection` when the
/// turn-16b skin took that file past the §2.1 ceiling — it is
/// the one part of General that is presentation with no
/// settings in it at all.
extension GeneralSection {
    /// What this install holds (#795, re-scoped) — its OWN card.
    ///
    /// It shipped as four lines under the wordmark and read as
    /// debug output rather than as content (owner, on device,
    /// 2026-08-16). General has no detail panel to move it to —
    /// that absence is a ruling, not a vacancy — so the answer
    /// is a card of its own, which is also what every other
    /// group on this page is.
    var installInventorySection: some View {
        SettingsSection(SettingsCatalog.general.installInventory) {
            InstallInventory(model: model)
        }
    }

    /// About (#68 §3.9): the wordmark as the canonical logo +
    /// name placement, version and the discreet support link
    /// beneath. Falls back to the pre-logo glyph row when the
    /// bundled resource is missing.
    var aboutSection: some View {
        SettingsSection(SettingsCatalog.general.aboutCard) {
            VStack(spacing: 10) {
                aboutBrand
                // The version and what changed in it are ONE
                // topic — "what you have" and "what arrived" —
                // so they sit closer to each other than either
                // does to the support ask below, which is an
                // unrelated request and reads best as the card's
                // last word (ui-designer, 2026-08-17). Uniform
                // spacing made all three equidistant and said
                // none of that.
                VStack(spacing: 4) {
                    Text(KiwiDeskVersion.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    releaseNotesLink
                }
                supportLink
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// What changed in the version above it (#570).
    ///
    /// Deliberately NOT the support link's shape: that link's
    /// heart and `.callout` are this card's one ask, and a second
    /// link drawn to match turns a personal plea into a links
    /// row, after which nothing on screen says which one the
    /// maker actually wants. So this one takes the plainer
    /// informational treatment — the caption's size, no symbol —
    /// and the asymmetry is the point rather than an oversight
    /// (ui-designer, 2026-08-17).
    ///
    /// No `.foregroundStyle` here on purpose: `linkHover()`
    /// already renders secondary at rest and lifts to primary on
    /// hover, so a foreground of our own would either fight it or
    /// be overwritten.
    ///
    /// A plain outbound `Link` rather than an in-app notes
    /// reader. `gui.md`'s "a picture whose object is not the
    /// draft goes in a sheet" does **not** reach this: its scope
    /// is content this app renders from data it owns, and release
    /// notes are neither — GitHub already renders them, with
    /// formatting and images a native sheet would not reproduce.
    @ViewBuilder var releaseNotesLink: some View {
        Link(destination: SupportLinks.releases) {
            Text(
                L("general.about.release_notes", "Release Notes")
            )
            .underline()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .linkHover()
    }

    /// The card's last word: the one ask, and the only link here
    /// carrying a symbol.
    @ViewBuilder var supportLink: some View {
        Link(destination: SupportLinks.koFi) {
            HStack(spacing: 4) {
                Image(systemName: "heart")
                Text(
                    L(
                        "general.about.support",
                        "Support KiwiDesk"
                    )
                )
                .underline()
            }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .linkHover()
    }

    /// The wordmark is artwork, not text, so its ink is baked at
    /// rasterization time rather than tinted at runtime: we ship
    /// two masters — forest lettering for light, mist-green for
    /// dark — and swap by `colorScheme`, so no backing card is
    /// needed and the mark melts into the pane in both. The
    /// **symbol** is identical in the two (#479); only the
    /// lettering is themed, and `BrandMasterParityTests` pins
    /// that.
    ///
    /// The fallback is the mark at 42 pt beside the name — the
    /// About block's size in the #678 §3 mark inventory, and the
    /// prototype's whole construction there, since it ships no
    /// wordmark asset. It is a fallback rather than the primary
    /// because the wordmark carries the same mark AND the
    /// lettering as one piece of artwork; drawing both would put
    /// two kiwis in one block. The generic `rectangle.3.group`
    /// this replaces was the one brand surface in the app with no
    /// brand in it.
    @ViewBuilder var aboutBrand: some View {
        if let wordmark {
            Image(nsImage: wordmark)
                .resizable()
                .scaledToFit()
                .frame(height: 130)
        } else {
            HStack(spacing: 12) {
                aboutFallbackMark
                Text(L("general.about.app_name", "KiwiDesk"))
                    .font(.headline)
                    .foregroundStyle(SettingsTheme.ink)
            }
        }
    }

    @ViewBuilder var aboutFallbackMark: some View {
        if let mark = BrandAssets.appMark {
            Image(nsImage: mark)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
        } else {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 30))
                .foregroundStyle(SettingsTheme.ink3)
        }
    }

    /// The dark master falls back to the light one if it is
    /// ever missing — a readable-but-imperfect degrade beats
    /// showing nothing.
    var wordmark: NSImage? {
        colorScheme == .dark
            ? BrandAssets.wordmarkDark ?? BrandAssets.wordmark
            : BrandAssets.wordmark
    }
}
