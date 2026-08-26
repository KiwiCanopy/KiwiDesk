import KiwiDeskCore
import SwiftUI

/// One screen of the tour, laid out the way the redesign
/// prototype lays it out (#828, 15a): progress pills at the top,
/// a left-aligned heading and copy, the step's own content, then
/// a footer row whose quiet hint sits opposite the one action.
///
/// **One primitive, five steps.** Before this each step composed
/// its own centred `VStack` and chose its own gaps, so the title
/// sat at a different height on every screen and "which button is
/// the action" was answered by stacking order rather than by
/// position. A tour is the one surface where every screen is
/// meant to read as the same screen with different words in it.
///
/// The footer is a ROW rather than a stack for the same reason
/// the prototype draws it that way: the hint is context for the
/// action beside it, and stacked centred buttons make a secondary
/// exit look like a second step.
struct OnboardingPage<Content: View, Action: View>: View {
    let title: String
    /// The body tier — `ink2`, and the sentence that says what
    /// this screen is about.
    let body1: String
    /// The quieter tier, drawn only when a screen has one. It is
    /// where a fact the user does not have to act on goes; the
    /// spaces step's Desktop↔Space nesting is the worked case.
    var footnote: String?
    /// Where that tier sits.
    ///
    /// Under the body by default, as the prototype draws it. A
    /// screen whose CONTENT is the thing to look at puts it at
    /// the bottom instead (owner, 2026-08-12): three paragraphs
    /// stacked above a grid of pictures buries the pictures, and
    /// the footnote is by definition the part that can wait.
    var footnoteAtBottom = false
    /// The bottom-left hint: what happens if the user does
    /// nothing, what the action does not commit them to, or
    /// where to go next.
    ///
    /// That third job is the closing screen's (#1019) and the
    /// doc was already narrower than the use before it — the
    /// retired "Tiled before? Open Settings" was a destination
    /// too.
    ///
    /// A **markdown** string: `**bold**` promotes a clause to
    /// `ink` inside the quiet grey, which is how the prototype
    /// draws the closing screen's reassurance. One key either
    /// way — the emphasis travels inside the sentence a
    /// translator owns, rather than splitting it into two keys an
    /// `HStack` would then be unable to reorder.
    var hint: String?
    /// A pulsing mark before the hint, for a hint that reports
    /// work still in flight — the boot-arranging count (#802).
    /// The MOTION is what it buys: an incrementing number is the
    /// honest signal but reads static between increments, and a
    /// footer sentence with no mark reads as a caption rather than
    /// as a report (owner, 2026-08-12). Neutral ink, not the
    /// attention token — there is nothing to attend to.
    var hintPulses = false
    /// Draws the hint a tier up — 13 pt on `ink2` rather than
    /// 12.5 pt on `ink3`.
    ///
    /// One screen takes it: the closing card, whose hint is the
    /// only route the tour offers to anything (#1019, on
    /// `ui-designer`'s reading 2026-08-26). Louder than the other
    /// four hints is the honest signal — those say what happens
    /// if you do nothing, this one says where to go — and it
    /// keeps the 2026-08-12 ruling that the pointer draws at body
    /// weight, honouring it INSIDE the footer slot rather than
    /// reversing it.
    ///
    /// A tier, never a shape: promoting it to a BUTTON would put
    /// a second control in a row the primitive deliberately draws
    /// as one action plus context, and would promise an in-app
    /// step for a link that opens a browser. #828's own ruling on
    /// this exact affordance is that it is a link in the
    /// sentence.
    var hintLeads = false
    /// A control drawn INSIDE the hint, at its own positional
    /// specifier (#828, owner ruled the closing screen's "Open
    /// Settings" is a link in the sentence, not a button above
    /// it).
    ///
    /// The sentence stays one localized frame and the link lands
    /// where the translation puts it — the obligation
    /// `CrossReferenceRow` already carries, and the reason four
    /// captions once ended on a bare preposition in five locales.
    var hintLink: HintLink?

    struct HintLink {
        let label: String
        let action: () -> Void
    }
    @ViewBuilder var content: Content
    @ViewBuilder var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(onboardingEmphasis(body1))
                    .font(.system(size: 14))
                    .foregroundStyle(SettingsTheme.ink2)
                    // Every copy tier wraps rather than truncates:
                    // a fixed window plus German is how the grant
                    // step shipped a clipped sentence (owner, on
                    // device, 2026-08-12).
                    .fixedSize(horizontal: false, vertical: true)
                if let footnote, !footnoteAtBottom {
                    footnoteText(footnote)
                }
            }
            content
            Spacer(minLength: 0)
            if let footnote, footnoteAtBottom {
                footnoteText(footnote)
            }
            HStack(alignment: .center, spacing: 10) {
                if let hint {
                    HStack(alignment: .center, spacing: 9) {
                        if hintPulses {
                            WaitingDot(ink: SettingsTheme.ink3)
                        }
                        hintView(hint)
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                } else {
                    Spacer(minLength: 0)
                }
                action
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func footnoteText(_ text: String) -> some View {
        Text(onboardingEmphasis(text))
            .font(.system(size: 12.5))
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The hint, with the link drawn at its own slot when the
    /// screen has one.
    ///
    /// `LinkedCaption`, not a `Button` in an `HStack`: a SwiftUI
    /// `.link` run gets no pointing-hand cursor (that file's
    /// on-device finding), and the cursor is the affordance that
    /// says a sentence is followable at all — the first cut here
    /// drew the label in the heading green with no underline and
    /// no cursor, which read as coloured text and nothing else
    /// (owner, 2026-08-12). It also line-breaks the sentence
    /// with `NSLayoutManager`, which is what ja/ko/zh need when
    /// the link lands mid-paragraph.
    @ViewBuilder
    private func hintView(_ text: String) -> some View {
        if let hintLink {
            let parts = LinkedCaption.split(frame: text)
            LinkedCaption(
                leading: parts.0,
                linkTitle: hintLink.label,
                trailing: parts.1,
                navigate: hintLink.action,
                pointSize: hintLeads ? 13 : 12.5,
                ink: NSColor(
                    hintLeads
                        ? SettingsTheme.ink2 : SettingsTheme.ink3
                )
            )
        } else {
            hintText(text)
        }
    }

    private func hintText(_ text: String) -> some View {
        Text(onboardingEmphasis(text))
            .font(.system(size: 12.5))
            .foregroundStyle(SettingsTheme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

}

/// `**bold**` inside a quiet tier, resolved to the strong ink
/// rather than to a heavier weight alone — the prototype's
/// closing screen sets its last clause that way, and the
/// emphasis has to travel INSIDE the one key so a translator
/// keeps the sentence whole.
///
/// Falls back to the raw string when the markdown will not
/// parse: a translator who breaks the asterisks should see their
/// sentence with stray characters in it, never an empty caption.
func onboardingEmphasis(_ text: String) -> AttributedString {
    guard
        var parsed = try? AttributedString(
            markdown: text,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )
    else { return AttributedString(text) }
    for run in parsed.runs
    where run.inlinePresentationIntent == .stronglyEmphasized {
        parsed[run.range].foregroundColor = SettingsTheme.ink
    }
    return parsed
}

/// The bordered card the prototype groups content into — white on
/// the page in light, one hairline, 12 pt radius.
///
/// A `ViewModifier` rather than a wrapper view so a step's content
/// stays readable at the call site, and one definition so the four
/// cards in this tour cannot drift apart.
struct OnboardingCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SettingsTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SettingsTheme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func onboardingCard() -> some View {
        modifier(OnboardingCard())
    }
}
