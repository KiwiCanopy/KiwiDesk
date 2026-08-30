import KiwiDeskCore
import SwiftUI

/// Preview of focused and unfocused window borders (#678).
struct FocusBorderPreview: View {
    let style: BorderStyle
    var sticky: StickyStyle? = nil

    var body: some View {
        picture
            .accessibilityElement()
            .accessibilityLabel(axLabel)
    }

    /// Spoken description based on active border and sticky states (#708).
    private var axLabel: String {
        stickyMark == nil
            ? L(
                "border.preview.ax",
                "Border preview: a focused window with its "
                    + "ring, beside an unfocused one."
            )
            : L(
                "border.preview.ax_sticky",
                "Border preview: a focused window with its ring "
                    + "and the everywhere-sticky mark, beside an "
                    + "unfocused one with the one-display mark."
            )
    }

    private var picture: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            HStack(spacing: 16) {
                window(
                    color: style.focusedColor,
                    ringed: true,
                    glow: style.glow,
                    mark: stickyMark
                )
                window(
                    color: style.unfocusedColor,
                    ringed: style.unfocusedEnabled,
                    glow: false,
                    mark: displayStickyMark
                )
            }
            .padding(14)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .opacity(style.enabled ? 1 : 0.4)
    }

    /// Everywhere-sticky mark for focused window (`GapsBordersPanelTests`).
    var stickyMark: (symbol: String, tint: Color)? {
        mark(for: .global)
    }

    /// Display-sticky mark for unfocused window (#445).
    var displayStickyMark: (symbol: String, tint: Color)? {
        mark(for: .display)
    }

    /// Resolves sticky symbol and tint for scope (#414).
    private func mark(
        for scope: StickyScope
    ) -> (symbol: String, tint: Color)? {
        guard let sticky, sticky.mark,
            let symbol = StickyStyle.symbolName(for: scope)
        else { return nil }
        return (symbol, .kiwiMark(sticky.color))
    }

    private func window(
        color: String,
        ringed: Bool,
        glow: Bool,
        mark: (symbol: String, tint: Color)?
    ) -> some View {
        let width = BorderPreviewScale.width(
            style.clampedWidth,
            to: 1...7
        )
        let glowRadius = scale(
            style.resolvedGlowBlur,
            from: BorderStyle.glowBlur(
                for: BorderStyle.minWidth
            )...BorderStyle.glowBlur(for: BorderStyle.maxWidth),
            to: 1...5
        )
        let radius: CGFloat =
            style.cornerStyle == .square ? 0 : 12
        return RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary.opacity(0.25))
            .overlay {
                if ringed {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(
                            Color(kiwiHex: color),
                            lineWidth: width
                        )
                        .shadow(
                            color: glow
                                ? Color(
                                    kiwiHex: BorderStyle.glowColor(
                                        from: color
                                    )
                                )
                                : .clear,
                            radius: glow ? glowRadius : 0
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                if let mark {
                    Image(systemName: mark.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mark.tint)
                        .padding(5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = min(max((value - src.lowerBound) / span, 0), 1)
        return dst.lowerBound
            + t * (dst.upperBound - dst.lowerBound)
    }
}
