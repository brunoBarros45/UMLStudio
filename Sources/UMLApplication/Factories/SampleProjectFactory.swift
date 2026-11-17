import CoreGraphics
import Foundation
import UMLDomain

/// Builds rich example UML 2.5 projects showcasing all 7 relationships and Gaphor-style multi-diagram model sharing.
public enum SampleProjectFactory {
    public static func makeEcommerceSample() -> UMLProject {
        let authenticatable = UMLClassifier(
            kind: .interface,
            name: "Authenticatable",
            stereotype: "interface",
            packageName: "Security",
            isAbstract: true,
            operations: [
                UMLOperation(
                    visibility: .public,
                    name: "authenticate",
                    parameters: [UMLParameter(name: "token", typeName: "String")],
                    returnType: "Bool",
                    isAbstract: true
                ),
                UMLOperation(visibility: .public, name: "revokeSession", returnType: "Void", isAbstract: true)
            ]
        )

        let user = UMLClassifier(
            kind: .abstractClass,
            name: "User",
            stereotype: "abstract",
            packageName: "Identity",
            isAbstract: true,
            attributes: [
                UMLAttribute(visibility: .protected, name: "id", typeName: "UUID", isReadOnly: true),
                UMLAttribute(visibility: .private, name: "email", typeName: "String"),
                UMLAttribute(visibility: .public, name: "activeUsersCount", typeName: "Int", isStatic: true)
            ],
            operations: [
                UMLOperation(visibility: .public, name: "getDisplayName", returnType: "String", isAbstract: true)
            ]
        )

        let customer = UMLClassifier(
            kind: .class,
            name: "Customer",
            packageName: "Identity",
            attributes: [
                UMLAttribute(visibility: .private, name: "loyaltyPoints", typeName: "Int", defaultValue: "0"),
                UMLAttribute(visibility: .private, name: "shippingAddress", typeName: "String", multiplicity: "0..1")
            ],
            operations: [
                UMLOperation(visibility: .public, name: "getDisplayName", returnType: "String"),
                UMLOperation(
                    visibility: .public,
                    name: "placeOrder",
                    parameters: [UMLParameter(name: "items", typeName: "[OrderLine]")],
                    returnType: "Order"
                )
            ]
        )

        let orderStatus = UMLClassifier(
            kind: .enumeration,
            name: "OrderStatus",
            stereotype: "enumeration",
            packageName: "Sales",
            enumLiterals: ["DRAFT", "CONFIRMED", "SHIPPED", "DELIVERED", "CANCELLED"]
        )

        let order = UMLClassifier(
            kind: .class,
            name: "Order",
            packageName: "Sales",
            attributes: [
                UMLAttribute(visibility: .public, name: "orderNumber", typeName: "String", isReadOnly: true),
                UMLAttribute(visibility: .private, name: "createdAt", typeName: "Date"),
                UMLAttribute(visibility: .public, name: "status", typeName: "OrderStatus", defaultValue: ".DRAFT")
            ],
            operations: [
                UMLOperation(visibility: .public, name: "calculateTotal", returnType: "Decimal"),
                UMLOperation(visibility: .public, name: "confirm", returnType: "Void")
            ]
        )

        let orderLine = UMLClassifier(
            kind: .class,
            name: "OrderLine",
            packageName: "Sales",
            attributes: [
                UMLAttribute(visibility: .private, name: "quantity", typeName: "Int", defaultValue: "1"),
                UMLAttribute(visibility: .private, name: "unitPrice", typeName: "Decimal")
            ],
            operations: [
                UMLOperation(visibility: .public, name: "subtotal", returnType: "Decimal")
            ]
        )

        let product = UMLClassifier(
            kind: .class,
            name: "Product",
            packageName: "Catalog",
            attributes: [
                UMLAttribute(visibility: .public, name: "sku", typeName: "String"),
                UMLAttribute(visibility: .public, name: "title", typeName: "String"),
                UMLAttribute(visibility: .private, name: "stock", typeName: "Int")
            ],
            operations: [
                UMLOperation(
                    visibility: .public,
                    name: "reserve",
                    parameters: [UMLParameter(name: "units", typeName: "Int")],
                    returnType: "Bool"
                )
            ]
        )

        let catalog = UMLClassifier(
            kind: .class,
            name: "Catalog",
            packageName: "Catalog",
            attributes: [
                UMLAttribute(visibility: .public, name: "name", typeName: "String")
            ],
            operations: [
                UMLOperation(
                    visibility: .public,
                    name: "findBySKU",
                    parameters: [UMLParameter(name: "sku", typeName: "String")],
                    returnType: "Product?"
                )
            ]
        )

        let paymentGateway = UMLClassifier(
            kind: .class,
            name: "PaymentGateway",
            packageName: "Billing",
            operations: [
                UMLOperation(
                    visibility: .public,
                    name: "charge",
                    parameters: [
                        UMLParameter(name: "order", typeName: "Order"),
                        UMLParameter(name: "amount", typeName: "Decimal")
                    ],
                    returnType: "Bool"
                )
            ]
        )

        let rRealization = UMLRelationship(
            kind: .realization,
            source: UMLRelationshipEnd(classifierID: user.id),
            target: UMLRelationshipEnd(classifierID: authenticatable.id)
        )
        let rInheritance = UMLRelationship(
            kind: .generalization,
            source: UMLRelationshipEnd(classifierID: customer.id),
            target: UMLRelationshipEnd(classifierID: user.id)
        )
        let rPlaces = UMLRelationship(
            kind: .directedAssociation,
            name: "places",
            source: UMLRelationshipEnd(classifierID: customer.id, roleName: "buyer", multiplicity: "1"),
            target: UMLRelationshipEnd(classifierID: order.id, roleName: "orders", multiplicity: "0..*")
        )
        let rStatus = UMLRelationship(
            kind: .association,
            name: "state",
            source: UMLRelationshipEnd(classifierID: order.id, multiplicity: "*"),
            target: UMLRelationshipEnd(classifierID: orderStatus.id, multiplicity: "1")
        )
        let rComposition = UMLRelationship(
            kind: .composition,
            name: "contains",
            source: UMLRelationshipEnd(classifierID: order.id, multiplicity: "1"),
            target: UMLRelationshipEnd(classifierID: orderLine.id, roleName: "lines", multiplicity: "1..*")
        )
        let rLineProduct = UMLRelationship(
            kind: .directedAssociation,
            name: "references",
            source: UMLRelationshipEnd(classifierID: orderLine.id, multiplicity: "*"),
            target: UMLRelationshipEnd(classifierID: product.id, roleName: "item", multiplicity: "1")
        )
        let rAggregation = UMLRelationship(
            kind: .aggregation,
            name: "groups",
            source: UMLRelationshipEnd(classifierID: catalog.id, multiplicity: "0..*"),
            target: UMLRelationshipEnd(classifierID: product.id, multiplicity: "0..*")
        )
        let rDependency = UMLRelationship(
            kind: .dependency,
            name: "uses",
            source: UMLRelationshipEnd(classifierID: order.id),
            target: UMLRelationshipEnd(classifierID: paymentGateway.id)
        )

        let classifiers = [authenticatable, user, customer, orderStatus, order, orderLine, product, catalog, paymentGateway]
        let relationships = [rRealization, rInheritance, rPlaces, rStatus, rComposition, rLineProduct, rAggregation, rDependency]
        let model = UMLModel(classifiers: classifiers, relationships: relationships)

        let mainNodes: [DiagramNodeView] = [
            DiagramNodeView(classifierID: authenticatable.id, position: CGPoint(x: 80, y: 64), headerColorHex: "#10B981"),
            DiagramNodeView(classifierID: user.id, position: CGPoint(x: 80, y: 240), headerColorHex: "#8B5CF6"),
            DiagramNodeView(classifierID: customer.id, position: CGPoint(x: 80, y: 464), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: orderStatus.id, position: CGPoint(x: 448, y: 64), headerColorHex: "#F59E0B"),
            DiagramNodeView(classifierID: order.id, position: CGPoint(x: 448, y: 272), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: paymentGateway.id, position: CGPoint(x: 816, y: 64), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: orderLine.id, position: CGPoint(x: 448, y: 496), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: product.id, position: CGPoint(x: 816, y: 480), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: catalog.id, position: CGPoint(x: 816, y: 256), headerColorHex: "#3B82F6")
        ]

        let mainEdges = relationships.map { DiagramEdgeView(relationshipID: $0.id, routingStyle: .orthogonal) }
        let mainDiagram = UMLDiagram(name: "Dominio E-Commerce (Completo)", nodes: mainNodes, edges: mainEdges)

        let salesNodes: [DiagramNodeView] = [
            DiagramNodeView(classifierID: customer.id, position: CGPoint(x: 96, y: 192), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: order.id, position: CGPoint(x: 432, y: 192), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: orderLine.id, position: CGPoint(x: 432, y: 416), headerColorHex: "#3B82F6"),
            DiagramNodeView(classifierID: paymentGateway.id, position: CGPoint(x: 784, y: 192), headerColorHex: "#3B82F6")
        ]
        let salesEdges = [rPlaces, rComposition, rDependency].map { DiagramEdgeView(relationshipID: $0.id, routingStyle: .orthogonal) }
        let salesDiagram = UMLDiagram(name: "Vista de Pedidos y Pagos", nodes: salesNodes, edges: salesEdges)

        return UMLProject(
            name: "Sistema E-Commerce UML",
            model: model,
            diagrams: [mainDiagram, salesDiagram]
        )
    }
}
