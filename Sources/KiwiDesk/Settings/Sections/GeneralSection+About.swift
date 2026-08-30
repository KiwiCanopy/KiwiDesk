import KiwiDeskCore
import SwiftUI

/// General ▸ About section displaying brand, version, notes, guide, and
/// support links (#68, #570, #1019).
extension GeneralSection {
    var aboutSection: some View {
        SettingsSection(SettingsCatalog.general.aboutCard) {
            VStack(spacing: 10) {
                aboutBrand
                VStack(spacing: 4) {
                    Text(KiwiDeskVersion.displayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    releaseNotesLink
                }
                guideLink
                askRow
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Link to GitHub release notes (#570).
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

    /// Link to user guide, registered with search index (#1019).
    @ViewBuilder var guideLink: some View {
        Link(destination: SupportLinks.guide) {
            Text(SettingsCatalog.general.guideLink.text)
                .underline()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .linkHover()
        .searchAnchored(SettingsCatalog.general.guideLink)
    }

    /// GitHub star and Ko-fi sponsor links.
    @ViewBuilder var askRow: some View {
        HStack(spacing: 14) {
            starLink
            supportLink
        }
    }

    @ViewBuilder var starLink: some View {
        Link(destination: SupportLinks.gitHub) {
            HStack(spacing: 4) {
                Image(systemName: "star")
                Text(
                    L(
                        "general.about.star",
                        "Star on GitHub"
                    )
                )
                .underline()
            }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .linkHover()
    }

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

    /// Wordmark artwork with dynamic dark/light master and fallback
    /// glyph (#479, `BrandMasterParityTests`). The fallback mark is
    /// 42 pt — the About block's size in the #678 §3 mark inventory.
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

    var wordmark: NSImage? {
        colorScheme == .dark
            ? BrandAssets.wordmarkDark ?? BrandAssets.wordmark
            : BrandAssets.wordmark
    }
}
