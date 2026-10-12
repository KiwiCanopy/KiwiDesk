import Foundation
import KiwiDeskCore

/// A row's title with the matched letters bold (#1875): the
/// search's ranges point into the entry's own `app` and `title`,
/// so each piece is marked before it is placed in the localized
/// frame, whatever order the frame puts them in.
@MainActor
enum JumpTitle {
    static func attributed(_ match: JumpSearch.Match) -> AttributedString {
        let entry = match.entry
        let app = marked(entry.app, match.appRange)
        guard !entry.title.isEmpty else { return app }
        let title = marked(entry.title, match.titleRange)
        var text = AttributedString()
        for segment in SentenceFrame(JumpRowText.titleFrame).segments {
            switch segment.slot {
            case .text(let literal):
                text += AttributedString(literal)
            case .argument(1):
                text += app
            case .argument(2):
                text += title
            case .argument:
                break
            }
        }
        return text
    }

    /// `text` with `range` strongly emphasized.
    static func marked(
        _ text: String,
        _ range: Range<String.Index>?
    ) -> AttributedString {
        var attributed = AttributedString(text)
        guard let range,
            let lower = AttributedString.Index(
                range.lowerBound,
                within: attributed
            ),
            let upper = AttributedString.Index(
                range.upperBound,
                within: attributed
            )
        else { return attributed }
        attributed[lower..<upper].inlinePresentationIntent =
            .stronglyEmphasized
        return attributed
    }
}
