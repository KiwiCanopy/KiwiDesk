import KiwiDeskCore
import SwiftUI

/// Pure scaling math mapping 0–100 pt gaps onto 1–14 pt preview span
/// (`GapPreviewScaleTests`).
enum GapPreviewScale {
    static let realMax: CGFloat = 100
    static let miniMin: CGFloat = 1
    static let miniMax: CGFloat = 14

    static func mini(_ real: CGFloat) -> CGFloat {
        let t = min(max(real / realMax, 0), 1)
        return miniMin + (miniMax - miniMin) * t.squareRoot()
    }
}

/// Visual 2×2 grid diagram demonstrating inner and outer gaps (#68, #812).
struct GapsDiagram: View {
    let outer: Gaps.Outer
    let inner: Gaps.Inner
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Shared damping animation gated by reduce motion (#1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    var body: some View {
        HStack(spacing: 12) {
            miniScreen
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
