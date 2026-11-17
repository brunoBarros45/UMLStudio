import Foundation

/// Root aggregate representing a saved `.umlproj` file.
public struct UMLProject: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var version: String
    public var model: UMLModel
    public var diagrams: [UMLDiagram]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Nuevo Proyecto UML",
        version: String = "1.0",
        model: UMLModel = UMLModel(),
        diagrams: [UMLDiagram] = [UMLDiagram(name: "Diagrama de Clases Principal")],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.model = model
        self.diagrams = diagrams
        self.updatedAt = updatedAt
    }

    public func diagram(for id: UUID) -> UMLDiagram? {
        diagrams.first { $0.id == id }
    }
}
