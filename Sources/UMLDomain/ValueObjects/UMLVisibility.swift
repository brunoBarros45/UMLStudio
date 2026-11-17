import Foundation

/// UML 2.5 member visibility notation.
public enum UMLVisibility: String, Codable, CaseIterable, Sendable, Hashable {
    case `public` = "+"
    case `private` = "-"
    case protected = "#"
    case package = "~"

    public var displayName: String {
        switch self {
        case .public: return "Public (+)"
        case .private: return "Private (-)"
        case .protected: return "Protected (#)"
        case .package: return "Package (~)"
        }
    }

    public var mermaidSymbol: String {
        rawValue
    }

    public init?(symbol: Character) {
        switch symbol {
        case "+": self = .public
        case "-": self = .private
        case "#": self = .protected
        case "~": self = .package
        default: return nil
        }
    }
}
