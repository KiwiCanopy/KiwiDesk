import SwiftUI

/// One window in KiwiVision's picture (#2103): a title bar and a
/// kind's content, drawn from the theme's card and ink tokens so
/// it takes whichever appearance the picture hands it.
struct KiwiVisionWindow: View {
    enum Kind: CaseIterable {
        case document, browser, chat, calendar
    }

    let kind: Kind
    /// Draws the content soft: the plate blurs what it covers.
    var soft = false
    /// The accent the picture's palette carries.
    var accent: Color = SettingsTheme.accent

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(SettingsTheme.card)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    titleBar
                    content
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .blur(radius: soft ? 3.5 : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var titleBar: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(SettingsTheme.ink3).frame(width: 3, height: 3)
            }
            Spacer()
        }
        .padding(.horizontal, 5)
        .frame(height: 9)
        .background(SettingsTheme.sunken)
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .document: document
        case .browser: browser
        case .chat: chat
        case .calendar: calendar
        }
    }

    private var document: some View {
        VStack(alignment: .leading, spacing: 4) {
            bar(0.45, height: 5, SettingsTheme.ink2)
            ForEach([0.92, 0.84, 0.88, 0.6, 0.8], id: \.self) {
                bar($0, height: 3, SettingsTheme.ink3)
            }
        }
    }

    private var browser: some View {
        VStack(alignment: .leading, spacing: 5) {
            bar(1, height: 6, SettingsTheme.ink3.opacity(0.25))
            RoundedRectangle(cornerRadius: 3)
                .fill(accent.opacity(0.55))
                .frame(height: 24)
            bar(0.75, height: 3, SettingsTheme.ink3)
            bar(0.55, height: 3, SettingsTheme.ink3)
        }
    }

    private var chat: some View {
        VStack(spacing: 4) {
            bubble(0.55, mine: false)
            bubble(0.45, mine: true)
            bubble(0.4, mine: false)
            bubble(0.6, mine: true)
        }
    }

    private var calendar: some View {
        let marked: [Int: Color] = [
            2: SettingsTheme.ink2, 8: accent.opacity(0.7),
            11: SettingsTheme.ink2, 15: SettingsTheme.ink2,
            24: SettingsTheme.ink2,
        ]
        return LazyVGrid(
            columns: Array(repeating: GridItem(spacing: 3), count: 7),
            spacing: 3
        ) {
            ForEach(0..<28, id: \.self) { day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(marked[day] ?? SettingsTheme.ink3.opacity(0.25))
                    .frame(height: 9)
            }
        }
    }

    private func bubble(_ width: CGFloat, mine: Bool) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(
                    mine
                        ? accent.opacity(0.7)
                        : SettingsTheme.ink3.opacity(0.35)
                )
                .frame(width: proxy.size.width * width)
                .frame(
                    maxWidth: .infinity,
                    alignment: mine ? .trailing : .leading
                )
        }
        .frame(height: 9)
    }

    private func bar(
        _ width: CGFloat,
        height: CGFloat,
        _ ink: Color
    ) -> some View {
        GeometryReader { proxy in
            Capsule().fill(ink).frame(width: proxy.size.width * width)
        }
        .frame(height: height)
    }
}
