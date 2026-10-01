import KiwiDeskCore
import SwiftUI

/// One Mouse & trackpad entry (#1726): a drawn picture, the
/// sentence that carries the gesture, and the entry's own control
/// where it has one. The picture moves while hovered, and once as
/// it appears where `playsOnAppear` says so (owner ruling
/// 2026-09-29), and rests on its key frame otherwise; under Reduce
/// Motion it never moves.
/// An entry whose `surface` is off greys its picture and sentence
/// and never its control — a greyed control says "you cannot
/// change this", and switching a setting on is always allowed.
struct GestureEntry<Picture: View, Control: View>: View {
    let text: String
    let surface: GestureSurface
    let settings: TilingSettings
    let pace: GesturePace
    /// The gesture itself is off (a cleared chord) though its
    /// surface is on: greyed the same way.
    let off: Bool
    /// The `?` after the sentence, which names the entry's control
    /// (#94), and what it is about for VoiceOver.
    let help: String?
    let helpSubject: String?
    /// Plays the picture once as the entry appears while set, and
    /// spends it, so a re-mount in the same open card rests.
    @Binding var playsOnAppear: Bool
    @ViewBuilder let picture: (CGFloat) -> Picture
    @ViewBuilder let control: () -> Control
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var autoplaying = false
    @State private var phase: CGFloat = 0

    /// Lets the card's expansion settle before the picture moves.
    private static var autoplayDelay: Double { 0.3 }

    init(
        _ text: String,
        surface: GestureSurface,
        settings: TilingSettings,
        pace: GesturePace = .quick,
        off: Bool = false,
        help: String? = nil,
        helpSubject: String? = nil,
        playsOnAppear: Binding<Bool> = .constant(false),
        @ViewBuilder picture: @escaping (CGFloat) -> Picture,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self._playsOnAppear = playsOnAppear
        self.help = help
        self.helpSubject = helpSubject
        self.text = text
        self.surface = surface
        self.settings = settings
        self.pace = pace
        self.off = off
        self.picture = picture
        self.control = control
    }

    var body: some View {
        GestureEntryLayout {
            // A new identity per moving state: a looping animation
            // ends with the view that ran it, since the rest frame
            // and the loop's target are the same value.
            GesturePlate { picture(moving ? phase : 1) }
                .id(moving)
                .accessibilityHidden(true)
                .modifier(dim)
            sentence
            control()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover(perform: hover)
        .onAppear {
            guard playsOnAppear else { return }
            playsOnAppear = false
            autoplay()
        }
    }

    private var moving: Bool { hovering || autoplaying }

    /// The grey an off surface puts on the picture and the
    /// sentence — never on the control, which stays live.
    private var dim: GreyOut {
        GreyOut(active: surface.isOff(settings) || off)
    }

    /// The sentence, and its `?` outside the grey: help stays
    /// readable whatever the surface says.
    private var sentence: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(dim)
            if let help {
                HelpButton(explanation: help, subject: helpSubject)
            }
        }
    }

    /// Restarts the gesture from its first frame, then loops it:
    /// two separate updates, since one that moved `phase` straight
    /// to where the rest frame already is would animate nothing.
    private func hover(_ inside: Bool) {
        hovering = inside && !reduceMotion
        autoplaying = false
        phase = 0
        guard hovering else { return }
        DispatchQueue.main.async {
            // The pointer may have left before this turn.
            guard hovering else { return }
            withAnimation(
                reduceMotion
                    ? nil
                    : pace.animation.repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }

    /// One run from the first frame, then the rest frame; a hover
    /// meanwhile takes over and ends it.
    private func autoplay() {
        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoplayDelay) {
            guard !hovering else { return }
            autoplaying = true
            phase = 0
            DispatchQueue.main.async {
                guard autoplaying else { return }
                withAnimation(reduceMotion ? nil : pace.animation) {
                    phase = 1
                } completion: {
                    autoplaying = false
                }
            }
        }
    }
}

extension GestureEntry where Control == EmptyView {
    init(
        _ text: String,
        surface: GestureSurface,
        settings: TilingSettings,
        pace: GesturePace = .quick,
        @ViewBuilder picture: @escaping (CGFloat) -> Picture
    ) {
        self.init(
            text,
            surface: surface,
            settings: settings,
            pace: pace,
            picture: picture
        ) { EmptyView() }
    }
}

/// How fast an entry's picture plays one loop.
enum GesturePace {
    /// A single motion, eased over the whole loop.
    case quick
    /// A short gesture in steps (a press, then a menu), at an even
    /// pace: its stages keep their timing, which one curve over the
    /// loop would bend.
    case steps
    /// A longer story in stages, at the same even pace; each stage
    /// eases itself (`gestureEase`).
    case story

    var animation: Animation {
        switch self {
        case .quick: return .easeInOut(duration: 1.6)
        case .steps: return .linear(duration: 2.4)
        case .story: return .linear(duration: 5)
        }
    }
}

/// The desktop-dark ground every gesture picture sits on, the
/// Home cards' plate (`SettingsTheme.previewPlate`), sized once.
struct GesturePlate<Content: View>: View {
    nonisolated static var size: CGSize {
        CGSize(width: 120, height: 72)
    }
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content()
        }
        .frame(
            width: Self.size.width,
            height: Self.size.height,
            alignment: .topLeading
        )
        .background(SettingsTheme.previewPlate)
        .clipShape(
            RoundedRectangle(cornerRadius: SettingsTheme.disclosureRadius)
        )
    }
}

/// The rule under every row of the card but its last: between two
/// entries, and between a group's last row and the next heading,
/// which stands farther from the rule than from its own first
/// entry, so it stays joined to what it owns. Never under a
/// heading, above the first (the card's hairline is there) or at
/// the card's end, which its edge closes.
struct GestureRule: View {
    var body: some View {
        SettingsTheme.hairline.frame(height: 1)
    }
}

/// A heading inside the drawer, one per place the hand is. A
/// heading after the first follows a group's closing rule, and
/// stands farther from it than from its own entries.
struct GestureGroupHeading: View {
    let title: String
    var followsGroup = false

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.groupHeading)
            .textCase(.uppercase)
            .padding(.top, followsGroup ? 14 : 6)
            .accessibilityAddTraits(.isHeader)
    }
}
