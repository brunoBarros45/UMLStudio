import Foundation
import Testing
@testable import UMLApplication
@testable import UMLDomain

@Suite("QuickEditParser Tests")
struct QuickEditParserTests {
    @Test("Parses complete attribute with visibility, type, multiplicity, default, and modifiers")
    func parsesCompleteAttribute() throws {
        let attr = try #require(QuickEditParser.parseAttribute("- items: OrderLine [1..*] = [] {static, readOnly}"))
        #expect(attr.visibility == .private)
        #expect(attr.name == "items")
        #expect(attr.typeName == "OrderLine")
        #expect(attr.multiplicity == "1..*")
        #expect(attr.defaultValue == "[]")
        #expect(attr.isStatic == true)
        #expect(attr.isReadOnly == true)
    }

    @Test("Parses attribute with array type brackets without misreading as multiplicity")
    func parsesArrayTypeAttribute() throws {
        let attr = try #require(QuickEditParser.parseAttribute("+ tags: [String] = [\"a\"]"))
        #expect(attr.visibility == .public)
        #expect(attr.name == "tags")
        #expect(attr.typeName == "[String]")
        #expect(attr.multiplicity == nil)
        #expect(attr.defaultValue == "[\"a\"]")
    }

    @Test("Parses operation with multiple parameters, nested generic types, return type, and modifiers")
    func parsesOperationWithMultipleParams() throws {
        let op = try #require(
            QuickEditParser.parseOperation("# calculate(rates: Dictionary<String, Double>, discount: Decimal = 0): Decimal {abstract}")
        )
        #expect(op.visibility == .protected)
        #expect(op.name == "calculate")
        #expect(op.parameters.count == 2)
        #expect(op.parameters[0].name == "rates")
        #expect(op.parameters[0].typeName == "Dictionary<String, Double>")
        #expect(op.parameters[1].name == "discount")
        #expect(op.parameters[1].typeName == "Decimal")
        #expect(op.parameters[1].defaultValue == "0")
        #expect(op.returnType == "Decimal")
        #expect(op.isAbstract == true)
        #expect(op.isStatic == false)
    }

    @Test("Parses classifier header with and without stereotype")
    func parsesClassifierHeader() {
        let withStereo = QuickEditParser.parseClassifierHeader("<<interface>> Authenticatable")
        #expect(withStereo.stereotype == "interface")
        #expect(withStereo.name == "Authenticatable")

        let plain = QuickEditParser.parseClassifierHeader("Customer")
        #expect(plain.stereotype == nil)
        #expect(plain.name == "Customer")
    }
}
