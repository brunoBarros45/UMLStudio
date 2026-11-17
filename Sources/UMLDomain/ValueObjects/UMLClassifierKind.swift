import Foundation

/// Standard UML 2.5 classifier archetypes supported by the modeler.
public enum UMLClassifierKind: String, Codable, CaseIterable, Sendable, Hashable {
    case `class` = "Class"
    case abstractClass = "Abstract Class"
    case interface = "Interface"
    case enumeration = "Enumeration"

    public var defaultStereotype: String? {
        switch self {
        case .class: return nil
        case .abstractClass: return "abstract"
        case .interface: return "interface"
        case .enumeration: return "enumeration"
        }
    }

    public var systemImageName: String {
        switch self {
        case .class: return "rectangle.split.3x1"
        case .abstractClass: return "rectangle.dashed"
        case .interface: return "circle.grid.cross"
        case .enumeration: return "list.bullet.rectangle"
        }
    }

    public var defaultHeaderHex: String {
        switch self {
        case .class: return "#3B82F6"
        case .abstractClass: return "#8B5CF6"
        case .interface: return "#10B981"
        case .enumeration: return "#F59E0B"
        }
    }
}
