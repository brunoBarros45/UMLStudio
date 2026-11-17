import Foundation

/// Parameter inside a UML operation signature.
public struct UMLParameter: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var typeName: String
    public var defaultValue: String?

    public init(
        id: UUID = UUID(),
        name: String,
        typeName: String = "Any",
        defaultValue: String? = nil
    ) {
        self.id = id
        self.name = name
        self.typeName = typeName
        self.defaultValue = defaultValue
    }

    public var formattedUML: String {
        var result = "\(name): \(typeName)"
        if let defaultValue, !defaultValue.isEmpty {
            result += " = \(defaultValue)"
        }
        return result
    }
}
