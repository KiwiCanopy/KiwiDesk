import KiwiDeskCore
import SwiftUI

/// The Space Bar card's multi-line row builders, split from
/// `SpaceBarCard+Rows.swift` for the file ceiling. Internal
/// (not private) only because the `row(for:)` switch lives in
/// the sibling extension file.
extension SpaceBarCard {
    /// Front-app segment title length (#171, #818, #901, #937,
    /// renamed by #1517). Greys on the toggle alone: vertical
    /// bars announce the name via AX even when not drawn.
    @ViewBuilder var titleCapRow: some View {
        StepperRow(
            label: L(
                "space_bar.front_app_title_cap",
                "Front app title length"
            ),
            value: style.frontAppTitleCap,
            in: AppBarStyle.titleCapRange,
            help: L(
                "space_bar.front_app_title_cap.help",
                "How many characters of the focused window's "
                    + "title the front-app segment shows before it "
                    + "is shortened."
            )
        )
        .modifier(
            GreyOut(
                active: !style.wrappedValue.showFrontApp,
                help: L(
                    "space_bar.title_cap.front_app_only",
                    "Only \u{201C}%1$@\u{201D} draws a title.",
                    L(
                        "space_bar.show_front_app",
                        "Show front app"
                    )
                )
            )
        )
    }

    /// Glyphs per Space stepper and live summary (#94). The
    /// anchor sits on the stepper alone: the row is two views,
    /// and an anchor on the pair would mount one id twice.
    @ViewBuilder var glyphCapRow: some View {
        StepperRow(
            label: L("space_bar.glyph_cap", "Glyphs per Space"),
            value: style.glyphCap,
            in: SpaceBarStyle.glyphCapRange,
            help: L(
                "space_bar.glyph_cap.help",
                "How many app glyphs a Space shows before the "
                    + "rest collapse into a +n badge. Adjacent "
                    + "windows of the same app count as one glyph."
            )
        )
        Text(
            L(
                "space_bar.glyph_cap.summary",
                "Up to %1$d app groups per Space; more collapse "
                    + "into a +n badge.",
                style.wrappedValue.resolvedGlyphCap
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
