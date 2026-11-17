import Foundation

/// Standard UML 2.5 relationship types between classifiers.
public enum UMLRelationshipKind: String, Codable, CaseIterable, Sendable, Hashable {
    case association = "Association"
    case directedAssociation = "Directed Association"
    case aggregation = "Aggregation"
    case composition = "Composition"
    case generalization = "Generalization"
    case realization = "Interface Realization"
    case dependency = "Dependency"

    public var displayName: String { rawValue }

    public var isDashed: Bool {
        switch self {
        case .realization, .dependency:
            return true
        case .association, .directedAssociation, .aggregation, .composition, .generalization:
            return false
        }
    }

    /// Standard Mermaid `classDiagram` arrow syntax from `source` to `target`.
    /// Note: For Generalization/Realization, `source` is the specialized/implementing class
    /// and `target` is the superclass/interface (`Source --|> Target`, `Source ..|> Target`).
    /// For Aggregation/Composition, `source` is the whole (`Whole o-- Part`, `Whole *-- Part`).
    public var mermaidArrow: String {
        switch self {
        case .association: return "--"
        case .directedAssociation: return "-->"
        case .aggregation: return "o--"
        case .composition: return "*--"
        case .generalization: return "--|>"
        case .realization: return "..|>"
        case .dependency: return "..>"
        }
    }

    public var systemImageName: String {
        switch self {
        case .association: return "line.diagonal"
        case .directedAssociation: return "arrow.up.right"
        case .aggregation: return "diamond"
        case .composition: return "diamond.fill"
        case .generalization: return "arrowtriangle.up"
        case .realization: return "arrow.up.and.line.horizontal.and.arrow.down"
        case .dependency: return "arrow.up.right.square"
        }
    }
}
