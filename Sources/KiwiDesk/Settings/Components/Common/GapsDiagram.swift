import KiwiDeskCore
import SwiftUI

/// Pure math for the gap preview: maps real 0–100 pt gap
/// values onto the miniature's 1–14 pt span. The square root
/// exaggerates the 0–20 pt range users actually live in and
/// compresses 60–100 pt, so slider drags stay perceptible
/// without the miniature blowing out. The 1 pt floor is
/// deliberate: even a real gap of 0 keeps a hairline seam so
/// the miniature's windows stay countable. The enum itself
/// touches no AppKit/SwiftUI API (`GapPreviewScaleTests`);
/// it lives here only until it grows more math.
enum GapPreviewScale {
    static let realMax: CGFloat = 100
    static let miniMin: CGFloat = 1
    static let miniMax: CGFloat = 14

    static func mini(_ real: CGFloat) -> CGFloat {
        let t = min(max(real / realMax, 0), 1)
        return miniMin + (miniMax - miniMin) * t.squareRoot()
    }
}

/// The live gap preview beside the legend (#68 §3.14): a
/// screen outline holding a 2×2 window grid, so both gap
/// kinds show on both axes — outer as the margin to the
/// screen edge, inner as the seams between the windows. Every
/// stored value maps through `GapPreviewScale` independently,
/// so per-edge asymmetry renders honestly as uneven margins.
/// It teaches the outer/inner vocabulary; it is deliberately
/// not a layout preview.
///
/// Left-aligned beside its legend (not centered like a
/// `SchematicCanvas`): this preview is **paired with the exact
/// controls in its card**, so it lines up flush with them as one
/// stack rather than reading as a standalone figure (see
/// design-decisions "Preview alignment splits on
/// standalone-vs-paired").
struct GapsDiagram: View {
    let outer: Gaps.Outer
    let inner: Gaps.Inner
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// The schematics' damping, gated (#1069) — the diagram
    /// still redraws at the staged gaps, it just stops
    /// travelling there. READ from `LayoutSchematic`, not
    /// re-spelled: the gate rule asks only that the ternary be
    /// local, and this diagram is one of that family's pictures,
    /// so a second copy of the duration is two tunings nothing
    /// holds equal (code review, #1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    var body: some View {
        HStack(spacing: 12) {
            miniScreen
                // A picture of the sliders' values; the legend
                // beside it and the sliders themselves speak
                // them, so the shapes say nothing (#812, as
                // `BarsPanelPreview` is treated).
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                legend(
                    L("gaps.outer_term", "Outer"),
                    L(
                        "gaps.outer_meaning",
                        "between windows and the screen edge"
                    )
                )
                legend(
                    L("gaps.inner_term", "Inner"),
                    L(
                        "gaps.inner_meaning",
                        "between neighboring windows"
                    )
                )
            }
            Spacer()
        }
    }

    private var miniScreen: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary.opacity(0.6))
            VStack(spacing: mini(inner.vertical)) {
                windowPair
                windowPair
            }
            .padding(.top, mini(outer.top))
            .padding(.bottom, mini(outer.bottom))
            .padding(.leading, mini(outer.left))
            .padding(.trailing, mini(outer.right))
        }
        .frame(width: 140, height: 96)
        .animation(damping, value: outer)
        .animation(damping, value: inner)
    }

    private var windowPair: some View {
        HStack(spacing: mini(inner.horizontal)) {
            windowRect
            windowRect
        }
    }

    private func mini(_ real: CGFloat) -> CGFloat {
        GapPreviewScale.mini(real)
    }

    private var windowRect: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(SettingsTheme.accent.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        SettingsTheme.accent.opacity(0.6)
                    )
            )
    }

    private func legend(
        _ term: String,
        _ meaning: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(term).fontWeight(.semibold)
            Text("— " + meaning)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
