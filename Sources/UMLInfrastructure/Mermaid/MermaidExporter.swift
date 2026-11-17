import Foundation
import UMLDomain

/// Generates Mermaid `classDiagram` syntax from a `UMLProject` or specific `UMLDiagram`.
public struct MermaidExporter: Sendable {
    public init() {}

    public func export(project: UMLProject, diagramID: UUID?) -> String {
        var lines: [String] = ["classDiagram"]

        let classifiers: [UMLClassifier]
        let relationships: [UMLRelationship]

        if let diagramID, let diagram = project.diagram(for: diagramID) {
            let visibleIDs = Set(diagram.nodes.map(\.classifierID))
            classifiers = project.model.classifiers.filter { visibleIDs.contains($0.id) }
            relationships = project.model.relationships.filter {
                visibleIDs.contains($0.source.classifierID) && visibleIDs.contains($0.target.classifierID)
            }
        } else {
            classifiers = project.model.classifiers
            relationships = project.model.relationships
        }

        let idToIdentifier = Dictionary(uniqueKeysWithValues: classifiers.map { ($0.id, sanitizeIdentifier($0.name)) })

        for classifier in classifiers {
            let ident = idToIdentifier[classifier.id] ?? sanitizeIdentifier(classifier.name)
            lines.append("    class \(ident) {")

            if let stereotype = classifier.effectiveStereotype {
                lines.append("        <<\(stereotype)>>")
            }

            if classifier.kind == .enumeration {
                for literal in classifier.enumLiterals {
                    lines.append("        \(literal)")
                }
            } else {
                for attr in classifier.attributes {
                    let staticSuffix = attr.isStatic ? "$" : ""
                    let multSuffix = attr.multiplicity.map { " [\($0)]" } ?? ""
                    let defaultSuffix = attr.defaultValue.map { " = \($0)" } ?? ""
                    let typePart = attr.typeName.isEmpty ? "" : ": \(attr.typeName)"
                    lines.append("        \(attr.visibility.mermaidSymbol)\(attr.name)\(typePart)\(multSuffix)\(defaultSuffix)\(staticSuffix)")
                }

                for op in classifier.operations {
                    let params = op.parameters.map(\.formattedUML).joined(separator: ", ")
                    let retPart = op.returnType.flatMap { $0.isEmpty ? nil : ": \($0)" } ?? ""
                    let modifierSuffix = op.isStatic ? "$" : (op.isAbstract ? "*" : "")
                    lines.append("        \(op.visibility.mermaidSymbol)\(op.name)(\(params))\(retPart)\(modifierSuffix)")
                }
            }

            lines.append("    }")
        }

        if !relationships.isEmpty {
            lines.append("")
        }

        for rel in relationships {
            guard let sourceName = idToIdentifier[rel.source.classifierID],
                  let targetName = idToIdentifier[rel.target.classifierID] else {
                continue
            }

            let sourceMult = rel.source.multiplicity.flatMap { $0.isEmpty ? nil : "\"\($0)\" " } ?? ""
            let targetMult = rel.target.multiplicity.flatMap { $0.isEmpty ? nil : " \"\($0)\"" } ?? ""
            let label = rel.name.flatMap { $0.isEmpty ? nil : " : \($0)" } ?? ""

            lines.append("    \(sourceName) \(sourceMult)\(rel.kind.mermaidArrow)\(targetMult) \(targetName)\(label)")
        }

        return lines.joined(separator: "\n")
    }

    private func sanitizeIdentifier(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let replaced = trimmed.replacingOccurrences(of: " ", with: "_")
        return replaced.isEmpty ? "UnnamedClass" : replaced
    }
}
