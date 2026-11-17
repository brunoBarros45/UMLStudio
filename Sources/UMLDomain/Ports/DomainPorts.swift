import CoreGraphics
import Foundation

/// Port for saving and loading `.umlproj` files.
public protocol ProjectRepositoryPort: Sendable {
    func save(_ project: UMLProject, to url: URL) throws
    func load(from url: URL) throws -> UMLProject
    func encode(_ project: UMLProject) throws -> Data
    func decode(from data: Data) throws -> UMLProject
}

/// Port for exporting and importing textual diagram representations (e.g., Mermaid `classDiagram`).
public protocol DiagramTextCodecPort: Sendable {
    func export(project: UMLProject, diagramID: UUID?) -> String
    func importCode(_ code: String, into project: inout UMLProject, diagramID: UUID?) throws
}

/// Strategy port for laying out diagram nodes automatically.
public protocol LayoutStrategyPort: Sendable {
    var strategyName: String { get }
    func layout(nodes: [DiagramNodeView], model: UMLModel, startOrigin: CGPoint) -> [UUID: CGPoint]
}
