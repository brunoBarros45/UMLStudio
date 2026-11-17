import Foundation

/// Canonical semantic UML 2.5 model repository (independent of visual diagrams).
public struct UMLModel: Codable, Hashable, Sendable {
    public var classifiers: [UMLClassifier]
    public var relationships: [UMLRelationship]

    public init(
        classifiers: [UMLClassifier] = [],
        relationships: [UMLRelationship] = []
    ) {
        self.classifiers = classifiers
        self.relationships = relationships
    }

    public func classifier(for id: UUID) -> UMLClassifier? {
        classifiers.first { $0.id == id }
    }

    public func classifier(named name: String) -> UMLClassifier? {
        classifiers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    public func relationship(for id: UUID) -> UMLRelationship? {
        relationships.first { $0.id == id }
    }

    public func relationships(involving classifierID: UUID) -> [UMLRelationship] {
        relationships.filter { $0.involves(classifierID: classifierID) }
    }

    public mutating func upsertClassifier(_ classifier: UMLClassifier) {
        if let index = classifiers.firstIndex(where: { $0.id == classifier.id }) {
            classifiers[index] = classifier
        } else {
            classifiers.append(classifier)
        }
    }

    public mutating func upsertRelationship(_ relationship: UMLRelationship) {
        if let index = relationships.firstIndex(where: { $0.id == relationship.id }) {
            relationships[index] = relationship
        } else {
            relationships.append(relationship)
        }
    }
}
