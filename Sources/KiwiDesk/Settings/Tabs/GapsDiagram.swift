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
struct GapsDiagram: View {
    let outer: Gaps.Outer
    let inner: Gaps.Inner

    var body: some View {
        HStack(spacing: 12) {
            miniScreen
            VStack(alignment: .leading, spacing: 4) {
                legend(
                    "Outer",
                    "between windows and the screen edge"
                )
                legend("Inner", "between neighboring windows")
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
        // Short enough to track a live slider drag without
        // visible lag; still smooths stepper/typed jumps.
        .animation(.easeOut(duration: 0.12), value: outer)
        .animation(.easeOut(duration: 0.12), value: inner)
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
            .fill(Color.accentColor.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        Color.accentColor.opacity(0.6)
                    )
            )
    }

    private func legend(
        _ term: String,
        _ meaning: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(term).bold()
            Text("— " + meaning)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
