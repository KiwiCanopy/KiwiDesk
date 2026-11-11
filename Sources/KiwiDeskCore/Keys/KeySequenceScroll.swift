import Foundation

/// How far a scroll key moves the key sequence panel's sheet
/// (#3175): lines or pages, signed, down positive. The GUI turns it
/// into points and does nothing where nothing overflows.
public enum KeySequenceScroll: Equatable, Sendable {
    case step(Int)
    case page(Int)
}
