import Foundation

/// The bar styles' stored keys and the verbs that write them.
enum BarStyleKeys {
    /// The setter field that writes a bar style's stored key
    /// `key`: a sparse `X_override` map is written by `set_X`'s
    /// optional scope argument, never by a verb of its own
    /// (config-vocabulary.md, #1948).
    static func setterField(of key: String) -> String {
        let suffix = "_override"
        return key.hasSuffix(suffix)
            ? String(key.dropLast(suffix.count)) : key
    }
}
