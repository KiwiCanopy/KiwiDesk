import Foundation

/// Whether a bar's shelf stays on screen (#761): `always`, or
/// `auto`, which hides it to an indicator the pointer reveals.
/// An edge hides only while every bar on it is `auto`
/// (`TilingSettings.barEdges(space:app:)`), and a hiding edge
/// reserves nothing, so a reveal draws over the windows.
public enum ShelfVisibility: String, Sendable, Codable, CaseIterable {
    case always
    case auto
}
