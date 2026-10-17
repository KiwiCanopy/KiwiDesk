import Foundation

/// Outcome of matching live monitors against saved profiles (#36, #53).
public enum ProfileMatch: Equatable {
    case exact(Profile)
    case countDefault(Profile)
    case none
}

/// Thrown for invalid profile names or name collisions.
public enum ProfileError: Error, CustomStringConvertible {
    case invalidName(String)
    case nameTaken(String)
    case dormantDefault(String)

    public var description: String {
        switch self {
        case .invalidName(let name):
            return "invalid profile name: '\(name)'"
        case .nameTaken(let name):
            return "a profile named '\(name)' already exists"
        case .dormantDefault(let name):
            return
                "'\(name)' holds no screen setup, so it cannot be "
                + "a screen count's default; load it first"
        }
    }
}
