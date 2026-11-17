import Foundation

/// Behavioral operation (method) belonging to a UML classifier.
public struct UMLOperation: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var visibility: UMLVisibility
    public var name: String
    public var parameters: [UMLParameter]
    public var returnType: String?
    public var isStatic: Bool
    public var isAbstract: Bool

    public init(
        id: UUID = UUID(),
        visibility: UMLVisibility = .public,
        name: String,
        parameters: [UMLParameter] = [],
        returnType: String? = "Void",
        isStatic: Bool = false,
        isAbstract: Bool = false
    ) {
        self.id = id
        self.visibility = visibility
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.isStatic = isStatic
        self.isAbstract = isAbstract
    }

    /// Standard UML 2.5 operation signature string.
    public var formattedUML: String {
        let paramList = parameters.map(\.formattedUML).joined(separator: ", ")
        var result = "\(visibility.rawValue) \(name)(\(paramList))"
        if let returnType, !returnType.isEmpty {
            result += ": \(returnType)"
        }
        return result
    }
}
