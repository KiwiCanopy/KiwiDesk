import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A recorder's caption is a line under its row, so a long one
/// leaves the row's title and the well where they were (#3553):
/// drawn in the recorder's trailing column it widened the column
/// into the title. A dead row is the seeded caption; its sentence
/// is far wider than the row. A short title leaves room either
/// way, so the recorder's own width is the measure.
///
/// Main-actor spend: two hosted rows in an offscreen window, each
/// spun until its well and title have laid out, then a 0.15 s
/// drain for the settled frames.
@Suite("Recorder captions leave the row in place (#3553)", .serialized)
@MainActor
struct RecorderCaptionLayoutTests {
    private final class Probe {
        var title: CGRect = .zero
        var field: CGRect = .zero
    }

    /// The one hang guard: a spin exits the moment its state holds.
    private static let hangGuard: TimeInterval = 30
    private static let width: CGFloat = 420

    private static let dead = ConflictReading(
        severity: .sidesTaken([]),
        sentence: String(
            repeating: "macOS answers this chord first. ",
            count: 4
        )
    )

    private func spin(until done: () -> Bool) {
        let deadline = Date().addingTimeInterval(Self.hangGuard)
        while !done(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// The well's frame, nil until it has laid out: the widest
    /// focus ring, at least `labelMinWidth`.
    private func well(in host: NSView) -> CGRect? {
        var rings: [CGRect] = []
        func walk(_ view: NSView) {
            if String(describing: type(of: view)) == "_FocusRingView" {
                rings.append(view.convert(view.bounds, to: host))
            }
            view.subviews.forEach(walk)
        }
        walk(host)
        return rings.max { $0.width < $1.width }.flatMap {
            $0.width >= KeyRecorderField.labelMinWidth ? $0 : nil
        }
    }

    /// The title's and the well's settled frames for one row.
    private func layout(reading: ConflictReading?) throws
        -> (title: CGRect, well: CGRect, field: CGRect)
    {
        let probe = Probe()
        let row = ShortcutKeyRow {
            Text(verbatim: "Toggle tiling")
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .named("host"))
                } action: {
                    probe.title = $0
                }
            Spacer()
            KeyRecorderField(
                name: "Toggle tiling",
                combo: "ctrl+alt+t",
                reading: reading,
                narrowing: nil,
                onRecord: { _ in },
                onClear: {}
            )
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named("host"))
            } action: {
                probe.field = $0
            }
        }
        .frame(width: Self.width, height: 200, alignment: .topLeading)
        .coordinateSpace(name: "host")
        .environmentObject(RecorderCoordinator())
        .environment(\.recorderSides, nil)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        let host = NSHostingView(rootView: row)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        spin { well(in: host) != nil && probe.title != .zero }
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        return (probe.title, try #require(well(in: host)), probe.field)
    }

    @Test("a long caption moves neither the title nor the well")
    func captionLeavesTheRow() throws {
        LocalizationManager.shared.select("en")
        let plain = try layout(reading: nil)
        let captioned = try layout(reading: Self.dead)
        #expect(plain.title.width > 0)
        // The host centres a taller stack, so frames are read
        // against the well.
        #expect(captioned.title.size == plain.title.size)
        #expect(captioned.title.minX == plain.title.minX)
        #expect(
            captioned.title.midY - captioned.well.midY
                == plain.title.midY - plain.well.midY
        )
        #expect(captioned.well.maxX == plain.well.maxX)
        #expect(captioned.well.width == plain.well.width)
        // The recorder's column stays its controls' width: a caption
        // in it would widen it to the sentence's.
        #expect(plain.field.width > 0)
        #expect(captioned.field.width == plain.field.width)
    }
}
