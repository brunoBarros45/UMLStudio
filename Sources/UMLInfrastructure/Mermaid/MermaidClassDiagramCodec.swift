import Foundation
import UMLDomain

/// Facade adapter implementing `DiagramTextCodecPort` for Mermaid `classDiagram`.
public struct MermaidClassDiagramCodec: DiagramTextCodecPort {
    private let exporter: MermaidExporter
    private let importer: MermaidImporter

    public init(
        exporter: MermaidExporter = MermaidExporter(),
        importer: MermaidImporter = MermaidImporter()
    ) {
        self.exporter = exporter
        self.importer = importer
    }

    public func export(project: UMLProject, diagramID: UUID?) -> String {
        exporter.export(project: project, diagramID: diagramID)
    }

    public func importCode(_ code: String, into project: inout UMLProject, diagramID: UUID?) throws {
        try importer.importCode(code, into: &project, diagramID: diagramID)
    }
}
