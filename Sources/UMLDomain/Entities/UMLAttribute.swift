import Foundation

/// Structural property belonging to a UML classifier.
public struct UMLAttribute: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var visibility: UMLVisibility
    public var name: String
    public var typeName: String
    public var multiplicity: String?
    public var defaultValue: String?
    public var isStatic: Bool
    public var isReadOnly: Bool

    public init(
        id: UUID = UUID(),
        visibility: UMLVisibility = .private,
        name: String,
        typeName: String = "String",
        multiplicity: String? = nil,
        defaultValue: String? = nil,
        isStatic: Bool = false,
        isReadOnly: Bool = false
    ) {
        self.id = id
        self.visibility = visibility
        self.name = name
        self.typeName = typeName
        self.multiplicity = multiplicity
        self.defaultValue = defaultValue
        self.isStatic = isStatic
        self.isReadOnly = isReadOnly
    }

    /// Standard UML 2.5 attribute presentation string.
    public var formattedUML: String {
        var result = "\(visibility.rawValue) \(name)"
        if !typeName.isEmpty {
            result += ": \(typeName)"
        }
        if let multiplicity, !multiplicity.isEmpty {
            result += " [\(multiplicity)]"
        }
        if let defaultValue, !defaultValue.isEmpty {
            result += " = \(defaultValue)"
        }
        var modifiers: [String] = []
        if isReadOnly {
            modifiers.append("readOnly")
        }
        if !modifiers.isEmpty {
            result += " {\(modifiers.joined(separator: ", "))}"
        }
        return result
    }
}
