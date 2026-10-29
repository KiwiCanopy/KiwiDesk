import SwiftUI

/// The shell's motion (#2737 ruling 13): only the `Simple |
/// Advanced` switch moves; a Home card swaps to its page at once.
enum ShellMotion {
    /// The shell's spring; every reader gates it at its call.
    static let spring = Animation.spring(response: 0.7, dampingFraction: 0.86)
    /// Simple fades out before Home's cards arrive.
    static let simpleFade: Double = 0.16
    /// Each card's lag behind the one before it, by grid index.
    static let stagger: Double = 0.025

    /// Which root the shell shows, the one value its animation keys
    /// on — Home to a page and back swaps unanimated.
    enum Branch: Equatable {
        case simple, advanced
    }
}

/// Home leaving under Simple fading in: dimmed and blurred (#2737
/// ruling 13).
struct ShellRecede: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 6 : 0)
            .opacity(active ? 0 : 1)
    }
}

/// A Home card arriving from the window's centre under the switch
/// (#2737 ruling 13): staggered by grid index, after Simple's fade.
struct HomeConverge: ViewModifier {
    let arrived: Bool
    let index: Int
    let viewport: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let away = !(arrived || reduceMotion)
        let centre = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        return
            content
            .visualEffect { effect, proxy in
                let frame = proxy.frame(in: .named(HomeConverge.space))
                return
                    effect
                    .offset(
                        x: away ? centre.x - frame.midX : 0,
                        y: away ? centre.y - frame.midY : 0
                    )
                    .scaleEffect(away ? 0.6 : 1)
                    .opacity(away ? 0 : 1)
            }
            .animation(
                reduceMotion
                    ? nil
                    : ShellMotion.spring.delay(
                        ShellMotion.simpleFade
                            + Double(index) * ShellMotion.stagger
                    ),
                value: arrived
            )
    }

    /// The viewport the cards fly from the centre of.
    nonisolated static let space = "homeViewport"
}
