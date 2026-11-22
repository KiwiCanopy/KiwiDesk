import Foundation
import Testing

@testable import KiwiDesk

/// A recorder's captions are lines under its row, never text in its
/// trailing column, which a long caption widened into the row's
/// label (#3553). Each recorder hands its lines to the slot and
/// draws them itself only where no row hosts it; each host sets the
/// slot and draws the lines at its text indent. Off the main actor;
/// a handful of file reads and one walk of the GUI tree.
@Suite("Recorder captions are row lines (#3553)")
struct RecorderCaptionSlotTests {
    private static let tree = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")
    private static let components = "Settings/Components/"

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(path),
                encoding: .utf8
            )
        ).filter { !$0.isWhitespace }
    }

    /// The brace-balanced run of `body`, empty where there is none.
    private static func body(_ text: String) -> Substring {
        guard let start = text.range(of: "varbody:someView{") else {
            return ""
        }
        var depth = 1
        var index = start.upperBound
        while index < text.endIndex, depth > 0 {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" { depth -= 1 }
            index = text.index(after: index)
        }
        return text[start.upperBound..<index]
    }

    /// The views a recorder's `body` may build itself.
    private static let layoutViews: Set<String> = [
        "VStack", "HStack", "RecorderCaptionLines",
    ]

    private static let recorders = [
        components + "Keybindings/Recorder/KeyRecorderField.swift",
        components + "Gestures/GestureChordRecorder.swift",
    ]

    /// Host → the slot it sets on its recorder and the lines it
    /// draws under the row.
    private static let hosts: [String: [String]] = [
        components + "Keybindings/Recorder/ShortcutKeyRow.swift": [
            ".environment(\\.recorderCaptionSlot,$captions)",
            "if!captions.isEmpty{RecorderCaptionLines(captions:captions)"
                + ".padding(.leading,SettingsMetrics.shortcutTextIndent)}",
        ],
        components + "Gestures/GestureListRow.swift": [
            ".environment(\\.recorderCaptionSlot,$keyCaptions)",
            "if!keyCaptions.isEmpty{"
                + "RecorderCaptionLines(captions:keyCaptions)}}"
                + ".padding(.leading,Self.textIndent)",
        ],
    ]

    @Test("recorders hand their lines to the row")
    func recordersPublish() throws {
        for path in Self.recorders {
            let text = try Self.source(path)
            for needle in [
                "ifcaptionSlot==nil{RecorderCaptionLines(captions:captions)}",
                ".publishesCaptions(captions,to:captionSlot)",
            ] {
                #expect(text.contains(needle), "\(path): \(needle)")
            }
            // Its body builds no view beside its stacks and the
            // lines view, and mounts nothing named a caption. Trade:
            // a view drawn through a helper property, or built by a
            // static factory (`Type.make(`), is unseen: the scan reads
            // `body` alone and sees a capitalised call only.
            let run = Self.body(text)
            #expect(!run.isEmpty, "\(path)")
            let built = Set(
                run.matches(of: /(?:^|\W)([A-Z]\w*)\(/)
                    .map { String($0.output.1) }
            )
            #expect(built.isSubset(of: Self.layoutViews), "\(path): \(built)")
            #expect(
                !run.replacingOccurrences(of: "publishesCaptions(", with: "")
                    .replacingOccurrences(
                        of: "RecorderCaptionLines(",
                        with: ""
                    ).contains("Caption"),
                "\(path)"
            )
        }
        let lines = try Self.source(
            Self.components + "Keybindings/Recorder/"
                + "KeyRecorderField+Captions.swift"
        )
        #expect(lines.contains("[deadLine,narrowingLine,tapOnceLine]"))
    }

    @Test("a recorder leaving clears the row's lines")
    func leavingClears() throws {
        let lines = try Self.source(
            Self.components + "Keybindings/Recorder/"
                + "RecorderCaptionLines.swift"
        )
        #expect(
            lines.contains(
                "onChange(of:captions,initial:true){_,nowin"
                    + "slot?.wrappedValue=now}"
                    + ".onDisappear{slot?.wrappedValue=[]}"
            )
        )
        #expect(
            lines.contains(
                "case.tapOnce(letdrawn,letspoken):"
                    + "plain(drawn).accessibilityLabel(spoken)"
            )
        )
    }

    @Test("rows host the lines under themselves")
    func hostsDraw() throws {
        for (path, needles) in Self.hosts {
            let text = try Self.source(path)
            for needle in needles {
                #expect(text.contains(needle), "\(path): \(needle)")
            }
        }
    }

    /// Every gesture recorder mount is a registered host; a new one
    /// joins `hosts` with the slot it sets.
    @Test("every gesture recorder mount hosts its lines")
    func gestureMountsAreHosts() throws {
        let own = Self.components + "Gestures/GestureChordRecorder.swift"
        let files = try FileManager.default.subpathsOfDirectory(
            atPath: Self.tree.path
        ).filter { $0.hasSuffix(".swift") && $0 != own }
        let mounts = try files.filter {
            try Self.source($0).contains("GestureChordRecorder(")
        }
        #expect(!mounts.isEmpty)
        let hosts = Set(Self.hosts.keys)
        #expect(Set(mounts).isSubset(of: hosts), "\(mounts)")
    }
}
