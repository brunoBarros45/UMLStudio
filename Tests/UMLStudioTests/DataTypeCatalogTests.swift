import Testing
@testable import UMLDomain

@Suite("UMLDataTypeCatalog Tests")
struct DataTypeCatalogTests {
    @Test("Orders common primitive types before collection and specialized types")
    func ordersCommonTypesFirst() {
        let types = UMLDataTypeCatalog.orderedCommonTypes
        let strIdx = types.firstIndex(of: "String")!
        let intIdx = types.firstIndex(of: "Int")!
        let boolIdx = types.firstIndex(of: "Bool")!
        let dictIdx = types.firstIndex(of: "Dictionary<String, Any>")!
        let anyIdx = types.firstIndex(of: "Any")!

        #expect(strIdx < intIdx)
        #expect(intIdx < boolIdx)
        #expect(boolIdx < dictIdx)
        #expect(dictIdx < anyIdx)
    }

    @Test("Appends model classifiers and preserves custom currentType")
    func appendsClassifiersAndCurrentType() {
        let customOrder = UMLClassifier(kind: .class, name: "Order")
        let options = UMLDataTypeCatalog.attributeTypes(including: [customOrder], currentType: "CustomDecimal")

        #expect(options.first == "String")
        #expect(options.contains("Order"))
        #expect(options.contains("CustomDecimal"))

        let returnOptions = UMLDataTypeCatalog.returnTypes(including: [customOrder], currentType: nil)
        #expect(returnOptions.first == "Void")
        #expect(returnOptions.contains("Order"))
    }
}
