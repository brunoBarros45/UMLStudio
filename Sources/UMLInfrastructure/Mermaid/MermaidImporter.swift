import CoreGraphics
import Foundation
import UMLApplication
import UMLDomain

public enum MermaidImportError: LocalizedError, Sendable {
    case emptyInput
    case invalidSyntax(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "El código Mermaid está vacío."
        case .invalidSyntax(let detail):
            return "Sintaxis Mermaid inválida: \(detail)"
        }
    }
}

/// Parses Mermaid `classDiagram` code into `UMLModel` classifiers/relationships
/// and positions nodes onto a target `UMLDiagram` using `HierarchicalLayoutStrategy`.
public struct MermaidImporter: Sendable {
    private let layoutStrategy: any LayoutStrategyPort

    public init(layoutStrategy: any LayoutStrategyPort = HierarchicalLayoutStrategy()) {
        self.layoutStrategy = layoutStrategy
    }

    public func importCode(_ rawCode: String, into project: inout UMLProject, diagramID: UUID?) throws {
        let lines = rawCode
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

        guard !lines.isEmpty else {
            throw MermaidImportError.emptyInput
        }

        var parsedClassifiers: [String: UMLClassifier] = [:]
        var classifierOrder: [String] = []
        var parsedRelationships: [ParsedRelation] = []
        var activeClassName: String?

        for line in lines {
            if line.lowercased().hasPrefix("classdiagram") || line.hasPrefix("direction ") {
                continue
            }

            // Closing block `}`
            if line == "}" {
                activeClassName = nil
                continue
            }

            // Inside `class Name { ... }`
            if let currentName = activeClassName {
                parseMemberLine(line, into: &parsedClassifiers[currentName]!)
                continue
            }

            // Opening `class Name {` or `class Name["Label"] {` or standalone `class Name`
            if line.hasPrefix("class ") {
                let afterKeyword = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if afterKeyword.hasSuffix("{") {
                    let rawName = String(afterKeyword.dropLast()).trimmingCharacters(in: .whitespaces)
                    let className = cleanClassToken(rawName)
                    ensureClassifier(named: className, map: &parsedClassifiers, order: &classifierOrder)
                    activeClassName = className
                } else {
                    let className = cleanClassToken(afterKeyword)
                    ensureClassifier(named: className, map: &parsedClassifiers, order: &classifierOrder)
                }
                continue
            }

            // Inline stereotype `<<interface>> Name`
            if line.hasPrefix("<<"), let endRange = line.range(of: ">>") {
                let stereotype = String(line[line.index(line.startIndex, offsetBy: 2)..<endRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let rest = String(line[endRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty {
                    let className = cleanClassToken(rest)
                    ensureClassifier(named: className, map: &parsedClassifiers, order: &classifierOrder)
                    applyStereotype(stereotype, to: &parsedClassifiers[className]!)
                }
                continue
            }

            // Inline member `ClassName : +attr: Type` (when not a relationship)
            if !containsRelationshipOperator(line), let colonRange = line.range(of: ":") {
                let lhs = String(line[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rhs = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !lhs.isEmpty && !rhs.isEmpty && !lhs.contains(" ") {
                    let className = cleanClassToken(lhs)
                    ensureClassifier(named: className, map: &parsedClassifiers, order: &classifierOrder)
                    parseMemberLine(rhs, into: &parsedClassifiers[className]!)
                    continue
                }
            }

            // Relationship line: `ClassA "1" *-- "1..*" ClassB : label`
            if let relation = parseRelationshipLine(line) {
                ensureClassifier(named: relation.sourceName, map: &parsedClassifiers, order: &classifierOrder)
                ensureClassifier(named: relation.targetName, map: &parsedClassifiers, order: &classifierOrder)
                parsedRelationships.append(relation)
            }
        }

        guard !classifierOrder.isEmpty else {
            throw MermaidImportError.invalidSyntax("No se encontraron clases ni relaciones reconocibles.")
        }

        // Merge or create classifiers in project.model
        var classifierIDByName: [String: UUID] = [:]
        for name in classifierOrder {
            guard let parsed = parsedClassifiers[name] else { continue }
            if let existing = project.model.classifier(named: name) {
                var merged = parsed
                merged.id = existing.id
                project.model.upsertClassifier(merged)
                classifierIDByName[name] = existing.id
            } else {
                project.model.upsertClassifier(parsed)
                classifierIDByName[name] = parsed.id
            }
        }

        // Create relationships in project.model
        var createdRelationshipIDs: [UUID] = []
        for rel in parsedRelationships {
            guard let sourceID = classifierIDByName[rel.sourceName],
                  let targetID = classifierIDByName[rel.targetName] else { continue }
            let relationship = UMLRelationship(
                kind: rel.kind,
                name: rel.label,
                source: UMLRelationshipEnd(classifierID: sourceID, multiplicity: rel.sourceMultiplicity),
                target: UMLRelationshipEnd(classifierID: targetID, multiplicity: rel.targetMultiplicity)
            )
            project.model.upsertRelationship(relationship)
            createdRelationshipIDs.append(relationship.id)
        }

        // Update target diagram or create a new one
        let targetDiagramIndex: Int
        if let diagramID, let existingIdx = project.diagrams.firstIndex(where: { $0.id == diagramID }) {
            targetDiagramIndex = existingIdx
        } else {
            let newDiagram = UMLDiagram(name: "Importado Mermaid \(project.diagrams.count + 1)")
            project.diagrams.append(newDiagram)
            targetDiagramIndex = project.diagrams.count - 1
        }

        for name in classifierOrder {
            guard let cid = classifierIDByName[name] else { continue }
            if !project.diagrams[targetDiagramIndex].contains(classifierID: cid) {
                let kindColor = project.model.classifier(for: cid)?.kind.defaultHeaderHex
                project.diagrams[targetDiagramIndex].nodes.append(
                    DiagramNodeView(classifierID: cid, position: .zero, headerColorHex: kindColor)
                )
            }
        }

        for relID in createdRelationshipIDs {
            if !project.diagrams[targetDiagramIndex].edges.contains(where: { $0.relationshipID == relID }) {
                project.diagrams[targetDiagramIndex].edges.append(
                    DiagramEdgeView(relationshipID: relID, routingStyle: .orthogonal)
                )
            }
        }

        // Apply hierarchical auto-layout cleanly
        let computedPositions = layoutStrategy.layout(
            nodes: project.diagrams[targetDiagramIndex].nodes,
            model: project.model,
            startOrigin: CGPoint(x: 80, y: 80)
        )
        for idx in project.diagrams[targetDiagramIndex].nodes.indices {
            let nodeID = project.diagrams[targetDiagramIndex].nodes[idx].id
            if let pos = computedPositions[nodeID] {
                project.diagrams[targetDiagramIndex].nodes[idx].position = pos
            }
        }
    }

    // MARK: - Line Parsers

    private struct ParsedRelation {
        let sourceName: String
        let targetName: String
        let kind: UMLRelationshipKind
        let sourceMultiplicity: String?
        let targetMultiplicity: String?
        let label: String?
    }

    private func ensureClassifier(
        named name: String,
        map: inout [String: UMLClassifier],
        order: inout [String]
    ) {
        if map[name] == nil {
            map[name] = UMLClassifier(kind: .class, name: name)
            order.append(name)
        }
    }

    private func cleanClassToken(_ token: String) -> String {
        var clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bracketIdx = clean.firstIndex(of: "[") {
            clean = String(clean[..<bracketIdx]).trimmingCharacters(in: .whitespaces)
        }
        if let tildeIdx = clean.firstIndex(of: "~") {
            clean = String(clean[..<tildeIdx]).trimmingCharacters(in: .whitespaces)
        }
        return clean.replacingOccurrences(of: "\"", with: "")
    }

    private func applyStereotype(_ rawStereotype: String, to classifier: inout UMLClassifier) {
        let lower = rawStereotype.lowercased()
        if lower == "interface" {
            classifier.kind = .interface
            classifier.stereotype = "interface"
            classifier.isAbstract = true
        } else if lower == "enumeration" || lower == "enum" {
            classifier.kind = .enumeration
            classifier.stereotype = "enumeration"
            classifier.isAbstract = false
        } else if lower == "abstract" {
            classifier.kind = .abstractClass
            classifier.stereotype = "abstract"
            classifier.isAbstract = true
        } else {
            classifier.stereotype = rawStereotype
        }
    }

    private func parseMemberLine(_ rawLine: String, into classifier: inout UMLClassifier) {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }

        if line.hasPrefix("<<") && line.hasSuffix(">>") {
            let inner = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
            applyStereotype(inner, to: &classifier)
            return
        }

        if classifier.kind == .enumeration && !line.contains("(") && !line.contains(":") {
            classifier.enumLiterals.append(line)
            return
        }

        // Check Mermaid `$` (static) or `*` (abstract) trailing classifier markers
        var isStatic = false
        var isAbstract = false
        if line.hasSuffix("$") {
            isStatic = true
            line = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        } else if line.hasSuffix("*") && !line.hasSuffix("]") {
            isAbstract = true
            line = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        if line.contains("(") {
            if var op = parseMermaidOperation(line) {
                op.isStatic = op.isStatic || isStatic
                op.isAbstract = op.isAbstract || isAbstract
                classifier.operations.append(op)
            }
        } else {
            if var attr = parseMermaidAttribute(line) {
                attr.isStatic = attr.isStatic || isStatic
                classifier.attributes.append(attr)
            }
        }
    }

    /// Supports both `+name: Type [mult] = def` and Mermaid-style `+Type name`.
    private func parseMermaidAttribute(_ line: String) -> UMLAttribute? {
        if line.contains(":") {
            return QuickEditParser.parseAttribute(line)
        }
        var work = line
        var visibility: UMLVisibility = .private
        if let first = work.first, let vis = UMLVisibility(symbol: first) {
            visibility = vis
            work = String(work.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        let parts = work.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return UMLAttribute(visibility: visibility, name: parts[1], typeName: parts[0])
        } else if parts.count == 1 && !parts[0].isEmpty {
            return UMLAttribute(visibility: visibility, name: parts[0], typeName: "String")
        }
        return nil
    }

    /// Supports both `+op(p: T): Ret` and Mermaid-style `+op(p: T) Ret`.
    private func parseMermaidOperation(_ line: String) -> UMLOperation? {
        return QuickEditParser.parseOperation(line)
    }

    private static let operatorSpecs: [(token: String, kind: UMLRelationshipKind, reversed: Bool)] = [
        ("<|--", .generalization, true),
        ("--|>", .generalization, false),
        ("<|..", .realization, true),
        ("..|>", .realization, false),
        ("o--", .aggregation, false),
        ("--o", .aggregation, true),
        ("*--", .composition, false),
        ("--*", .composition, true),
        ("<--", .directedAssociation, true),
        ("-->", .directedAssociation, false),
        ("<..", .dependency, true),
        ("..>", .dependency, false),
        ("--", .association, false),
        ("..", .dependency, false)
    ]

    private func containsRelationshipOperator(_ line: String) -> Bool {
        Self.operatorSpecs.contains { line.contains($0.token) }
    }

    private func parseRelationshipLine(_ line: String) -> ParsedRelation? {
        // Split optional `: label` outside quotes
        var mainPart = line
        var label: String?

        if let colonIndex = findUnquotedColon(in: line) {
            mainPart = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let rawLabel = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            if !rawLabel.isEmpty {
                label = rawLabel
            }
        }

        for spec in Self.operatorSpecs {
            if let range = mainPart.range(of: spec.token) {
                let leftSide = String(mainPart[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rightSide = String(mainPart[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                guard let (leftName, leftMult) = parseEndpoint(leftSide, multAtEnd: true),
                      let (rightName, rightMult) = parseEndpoint(rightSide, multAtEnd: false) else {
                    continue
                }

                if spec.reversed {
                    return ParsedRelation(
                        sourceName: rightName,
                        targetName: leftName,
                        kind: spec.kind,
                        sourceMultiplicity: rightMult,
                        targetMultiplicity: leftMult,
                        label: label
                    )
                } else {
                    return ParsedRelation(
                        sourceName: leftName,
                        targetName: rightName,
                        kind: spec.kind,
                        sourceMultiplicity: leftMult,
                        targetMultiplicity: rightMult,
                        label: label
                    )
                }
            }
        }
        return nil
    }

    private func parseEndpoint(_ segment: String, multAtEnd: Bool) -> (name: String, multiplicity: String?)? {
        let trimmed = segment.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Check quoted multiplicity: e.g., `Order "1"` or `"1..*" OrderLine`
        if let firstQuote = trimmed.firstIndex(of: "\""),
           let lastQuote = trimmed.lastIndex(of: "\""),
           firstQuote < lastQuote {
            let mult = String(trimmed[trimmed.index(after: firstQuote)..<lastQuote])
                .trimmingCharacters(in: .whitespaces)
            let remainder: String
            if multAtEnd {
                remainder = String(trimmed[..<firstQuote]).trimmingCharacters(in: .whitespaces)
            } else {
                remainder = String(trimmed[trimmed.index(after: lastQuote)...]).trimmingCharacters(in: .whitespaces)
            }
            let name = cleanClassToken(remainder)
            guard !name.isEmpty else { return nil }
            return (name, mult.isEmpty ? nil : mult)
        }

        let name = cleanClassToken(trimmed)
        guard !name.isEmpty else { return nil }
        return (name, nil)
    }

    private func findUnquotedColon(in text: String) -> String.Index? {
        var inQuotes = false
        for idx in text.indices {
            if text[idx] == "\"" { inQuotes.toggle() }
            if !inQuotes && text[idx] == ":" {
                return idx
            }
        }
        return nil
    }
}
