import KiwiDeskCore
import SwiftUI

/// Width × Height of a minimum window size on one line, each with
/// its own stepper (#2237). A nil axis is the master's "Mixed": an
/// empty field whose prompt says so, stepping from `base`.
struct MinSizeFields: View {
    /// Each axis's spoken name ("Stack width").
    let name: (MinSizeAxis) -> String
    let width: Int?
    let height: Int?
    let base: (MinSizeAxis) -> Int
    let set: (MinSizeAxis, Int) -> Void
    /// Each axis's search anchor; nil for the master, whose
    /// section is the anchor.
    var anchor: (MinSizeAxis) -> SettingsControl? = { _ in nil }

    static let range = 100...800
    static let step = 10

    var body: some View {
        HStack(spacing: 6) {
            MinSizeAxisField(
                letter: L("layout_defaults.min_size.w", "W"),
                label: name(.width),
                value: width,
                base: base(.width)
            ) { set(.width, $0) }
            .searchAnchored(optional: anchor(.width))
            Text(verbatim: "×")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            MinSizeAxisField(
                letter: L("layout_defaults.min_size.h", "H"),
                label: name(.height),
                value: height,
                base: base(.height)
            ) { set(.height, $0) }
            .searchAnchored(optional: anchor(.height))
            Text(verbatim: "pt")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

/// One axis: a letter, a field and a stepper.
struct MinSizeAxisField: View {
    let letter: String
    let label: String
    let value: Int?
    let base: Int
    let set: (Int) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    private static var mixed: String {
        L("layout_defaults.min_size.mixed", "Mixed")
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(letter)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(Self.mixed))
                .labelsHidden()
                .accessibilityLabel(label)
                .accessibilityValue(value.map { "\($0) pt" } ?? Self.mixed)
                .frame(width: 76)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .textFieldStyle(.roundedBorder)
                .commitsOnSave($focused, commit)
            Stepper(label) {
                set(clamped((value ?? base) + MinSizeFields.step))
            } onDecrement: {
                set(clamped((value ?? base) - MinSizeFields.step))
            }
            .labelsHidden()
            .accessibilityValue(value.map { "\($0) pt" } ?? Self.mixed)
        }
        .onAppear { text = value.map(String.init) ?? "" }
        .onChange(of: value) { _, now in
            if !focused { text = now.map(String.init) ?? "" }
        }
    }

    private func clamped(_ raw: Int) -> Int {
        min(
            max(raw, MinSizeFields.range.lowerBound),
            MinSizeFields.range.upperBound
        )
    }

    /// Writes only an edit: a value stored outside the stepper's
    /// band (Lua) survives the field merely losing focus.
    private func commit() {
        guard text != (value.map(String.init) ?? "") else { return }
        guard let parsed = Int(text) else {
            text = value.map(String.init) ?? ""
            return
        }
        set(clamped(parsed))
        text = String(clamped(parsed))
    }
}

extension View {
    /// `searchAnchored(_:)` where an anchor exists.
    @ViewBuilder
    fileprivate func searchAnchored(
        optional control: SettingsControl?
    ) -> some View {
        if let control {
            searchAnchored(control)
        } else {
            self
        }
    }
}
