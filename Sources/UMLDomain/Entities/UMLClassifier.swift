import Foundation

/// Canonical semantic UML classifier living in the `UMLModel` repository.
/// Visual position and layout live separately in `DiagramNodeView` (Gaphor-style model/diagram separation).
public struct UMLClassifier: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: UMLClassifierKind
    public var name: String
    public var stereotype: String?
    public var packageName: String?
    public var isAbstract: Bool
    public var attributes: [UMLAttribute]
    public var operations: [UMLOperation]
    public var enumLiterals: [String]
    public var documentation: String

    public init(
        id: UUID = UUID(),
        kind: UMLClassifierKind = .class,
        name: String,
        stereotype: String? = nil,
        packageName: String? = nil,
        isAbstract: Bool? = nil,
        attributes: [UMLAttribute] = [],
        operations: [UMLOperation] = [],
        enumLiterals: [String] = [],
        documentation: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.stereotype = stereotype ?? kind.defaultStereotype
        self.packageName = packageName
        self.isAbstract = isAbstract ?? (kind == .abstractClass || kind == .interface)
        self.attributes = attributes
        self.operations = operations
        self.enumLiterals = enumLiterals
        self.documentation = documentation
    }

    public var effectiveStereotype: String? {
        if let stereotype, !stereotype.trimmingCharacters(in: .whitespaces).isEmpty {
            return stereotype
        }
        return kind.defaultStereotype
    }
}
