import SwiftUI

/// The pieces `SettingsSlider` draws for a darker/lighter scale
/// (`lightness`).
extension SettingsSlider {
    static let endSpacing: CGFloat = 6
    static let notchWidth: CGFloat = 1.5
    private static let endGlyphSize: CGFloat = 11

    /// Decorative: the spoken value already says darker or lighter.
    func endGlyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: Self.endGlyphSize))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    /// Black and white here MEAN darker and lighter, in both
    /// appearances; faint so the accent fill still leads.
    var lightnessRamp: some View {
        Capsule().fill(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.10), location: 0),
                    .init(color: .clear, location: 0.48),
                    .init(color: .clear, location: 0.52),
                    .init(color: .white.opacity(0.20), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    /// At the origin the knob covers the notch, so the notch shows
    /// just above and below it — the scale's zero, like a dial.
    func originMarks(knobHeight: CGFloat) -> some View {
        VStack(spacing: knobHeight + 2) {
            originMark
            originMark
        }
        .accessibilityHidden(true)
    }

    private var originMark: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.45))
            .frame(width: Self.notchWidth, height: 4)
    }
}
