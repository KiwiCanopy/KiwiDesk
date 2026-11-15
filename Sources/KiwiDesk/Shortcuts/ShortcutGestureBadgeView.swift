import AppKit
import KiwiDeskCore
import SwiftUI

/// A shortcuts panel row's gesture (#1873 ▸ Ruling 2026-11-15): the
/// keys and the gesture's glyph at the row's text size, then "+N"
/// for the other gestures of the same action, which its hover
/// lists.
struct ShortcutGestureBadgeView: View {
    let badges: [ShortcutGestureBadge]

    /// The glyph's side: the callout text's cap height and a little,
    /// the size the badge renders were approved at (owner).
    static let side: CGFloat = 13

    var body: some View {
        if let first = badges.first {
            HStack(spacing: 4) {
                if !first.key.chord.isEmpty {
                    Text(verbatim: first.chord)
                        .font(.callout)
                }
                glyph(first)
                if badges.count > 1 {
                    Text(verbatim: "+\(badges.count - 1)")
                        .font(.caption)
                        .help(others)
                }
            }
            .foregroundStyle(.secondary)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
        }
    }

    private func glyph(_ badge: ShortcutGestureBadge) -> some View {
        Group {
            if let custom = CustomGlyph(name: badge.symbol) {
                Image(nsImage: custom.image)
                    .renderingMode(.template)
                    .resizable()
            } else {
                Image(systemName: badge.symbol)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: Self.side, height: Self.side)
    }

    /// The hover over "+N": each other gesture, on a line of its own.
    private var others: String {
        badges.dropFirst().map { badge in
            badge.key.chord.isEmpty
                ? badge.words : badge.chord + " " + badge.words
        }
        .joined(separator: "\n")
    }

    private var spoken: String {
        badges.map(\.spoken).joined(separator: "; ")
    }
}
