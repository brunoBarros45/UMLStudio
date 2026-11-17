import Foundation

/// One endpoint of a UML relationship connecting to a classifier.
public struct UMLRelationshipEnd: Codable, Hashable, Sendable {
    public var classifierID: UUID
    public var roleName: String?
    public var multiplicity: String?
    public var isNavigable: Bool

    public init(
        classifierID: UUID,
        roleName: String? = nil,
        multiplicity: String? = nil,
        isNavigable: Bool = true
    ) {
        self.classifierID = classifierID
        self.roleName = roleName
        self.multiplicity = multiplicity
        self.isNavigable = isNavigable
    }
}

/// Semantic UML 2.5 relationship between two classifiers in `UMLModel`.
public struct UMLRelationship: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: UMLRelationshipKind
    public var name: String?
    public var stereotype: String?
    public var source: UMLRelationshipEnd
    public var target: UMLRelationshipEnd

    public init(
        id: UUID = UUID(),
        kind: UMLRelationshipKind,
        name: String? = nil,
        stereotype: String? = nil,
        source: UMLRelationshipEnd,
        target: UMLRelationshipEnd
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.stereotype = stereotype
        self.source = source
        self.target = target
    }

    public func involves(classifierID: UUID) -> Bool {
        source.classifierID == classifierID || target.classifierID == classifierID
    }
}
