import Foundation

/// An empty Pocket's click (#2941 ▸ Ruling): a header, the lines
/// saying how a window goes in, each chord drawn live and spoken
/// as words, and the rows landing on the Pocket's Settings.
extension BarPeekContent {
    struct Empty: Equatable {
        /// One instruction, its chord drawn in `drawn` and named in
        /// words in `spoken`.
        struct Line: Equatable {
            let drawn: String
            let spoken: String
        }

        /// A trailing row: its title and where it lands.
        struct Row: Equatable {
            let title: String
            let landing: SettingsLanding
        }

        let title: String
        let lines: [Line]
        let rows: [Row]

        /// What VoiceOver reads for the header and its lines, as one
        /// text; a line break, so no locale owes a joining stop.
        var spoken: String {
            ([title] + lines.map(\.spoken)).joined(separator: "\n")
        }
    }
}
