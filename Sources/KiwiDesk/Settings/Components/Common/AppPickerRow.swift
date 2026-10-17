import AppKit
import SwiftUI

/// One row of the shared app picker (#2103 ruling 27): the app's
/// icon and name, one line, spoken as one element. A process with
/// no bundle id (SketchyBar) shows the generic program icon and the
/// name macOS lists it under.
struct AppPickerRow: View {
    let name: String
    /// Nil for a process without a bundle id.
    let bundleID: String?
    /// The picker's cursor sits here (`DropdownCursor`).
    var onCursor = false
    /// Every pointer event over the row, for `DropdownCursor.hover`.
    var onPoint: () -> Void = {}
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: AppIconCache.side, height: AppIconCache.side)
                Text(name)
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(DropdownRowStyle.ink(onCursor))
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .dropdownCursorRow(onCursor, onPoint: onPoint)
        .accessibilityElement(children: .combine)
    }

    private var icon: NSImage {
        guard let bundleID else { return AppIconCache.shared.processIcon }
        return AppIconCache.shared.icon(forBundleID: bundleID)
    }
}
