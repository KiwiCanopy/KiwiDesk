import SwiftUI

/// A Desktop overview icon's title hint: a tooltip never shows while
/// KiwiDesk is not the active app, and KiwiHub never activates it, so
/// a rested icon hands its title and frame up and the side draws the
/// hint above its scroll, never clipped by a column.
struct DesktopTitleHint: Equatable {
    let title: String
    let anchor: Anchor<CGRect>

    /// How long the pointer rests before the title shows, about a
    /// tooltip's wait.
    static let delay: Duration = .milliseconds(700)
    /// The widest a hint grows before it truncates.
    static let width: CGFloat = 240
}

struct DesktopTitleHintKey: PreferenceKey {
    static let defaultValue: DesktopTitleHint? = nil
    static func reduce(
        value: inout DesktopTitleHint?,
        nextValue: () -> DesktopTitleHint?
    ) {
        value = value ?? nextValue()
    }
}

/// Places the hint over the side: above its icon, below it where the
/// side's top edge would cut it, and inside the side's width.
struct DesktopTitleHintLayout: Layout {
    let target: CGRect
    var gap: CGFloat = 4

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let hint = subviews.first else { return }
        let size = hint.sizeThatFits(.unspecified)
        let at = Self.origin(of: size, over: target, in: bounds.size, gap)
        hint.place(
            at: CGPoint(x: bounds.minX + at.x, y: bounds.minY + at.y),
            proposal: ProposedViewSize(size)
        )
    }

    /// The hint's top-left in the side's space: centred over its
    /// icon, inside the side's width, flipped below where the top
    /// would cut it.
    static func origin(
        of size: CGSize,
        over target: CGRect,
        in side: CGSize,
        _ gap: CGFloat
    ) -> CGPoint {
        let x = min(
            max(target.midX - size.width / 2, gap),
            side.width - size.width - gap
        )
        let above = target.minY - gap - size.height
        return CGPoint(x: x, y: above >= 0 ? above : target.maxY + gap)
    }
}

/// The hint's capsule: the shelf's group badge pair, the solid fill
/// and ink the strip's window count wears, so it reads over any
/// glass and any icon.
struct DesktopTitleHintView: View {
    let title: String
    @Environment(\.kiwiHubPaint) private var paint

    var body: some View {
        Text(title)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            // Its own width up to the cap, never an icon's.
            .frame(maxWidth: DesktopTitleHint.width)
            .fixedSize()
            .foregroundStyle(paint.badgeInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(paint.badge))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Draws the hint a rested icon below hands up.
    func desktopTitleHints() -> some View {
        overlayPreferenceValue(DesktopTitleHintKey.self) { hint in
            if let hint {
                GeometryReader { proxy in
                    DesktopTitleHintLayout(target: proxy[hint.anchor]) {
                        DesktopTitleHintView(title: hint.title)
                    }
                }
            }
        }
    }
}
