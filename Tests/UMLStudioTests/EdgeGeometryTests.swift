import CoreGraphics
import Testing
@testable import UMLApplication
@testable import UMLDomain

@Suite("Edge Routing Geometry Tests")
struct EdgeGeometryTests {
    @Test("Computes exact intersection point on rectangle border")
    func computesRectIntersection() {
        let rect = CGRect(x: 100, y: 100, width: 200, height: 100)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let rightHit = EdgePathCalculator.rectIntersection(from: center, toward: CGPoint(x: 500, y: 150), rect: rect)
        #expect(abs(rightHit.x - 300) < 0.001)
        #expect(abs(rightHit.y - 150) < 0.001)

        let bottomHit = EdgePathCalculator.rectIntersection(from: center, toward: CGPoint(x: 200, y: 400), rect: rect)
        #expect(abs(bottomHit.x - 200) < 0.001)
        #expect(abs(bottomHit.y - 200) < 0.001)
    }

    @Test("Generates orthogonal Z-shaped path when boxes are offset on both axes")
    func generatesOrthogonalPath() {
        let source = CGRect(x: 0, y: 0, width: 200, height: 100)
        let target = CGRect(x: 400, y: 120, width: 200, height: 100)

        let points = EdgePathCalculator.computePathPoints(
            routingStyle: .orthogonal,
            sourceRect: source,
            targetRect: target
        )
        #expect(points.count == 4)
        #expect(points.first == CGPoint(x: 200, y: 50))
        #expect(points.last == CGPoint(x: 400, y: 170))
    }

    @Test("Generates self-loop path when source equals target")
    func generatesSelfLoopPath() {
        let box = CGRect(x: 100, y: 100, width: 220, height: 120)
        let points = EdgePathCalculator.computePathPoints(
            routingStyle: .orthogonal,
            sourceRect: box,
            targetRect: box,
            isSelfLoop: true
        )
        #expect(points.count == 5)
    }

    @Test("Hit-testing calculates accurate distance to polyline segments")
    func hitTestingDistance() {
        let polyline = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]
        let nearDist = EdgePathCalculator.distanceFromPoint(CGPoint(x: 50, y: 4), toPolyline: polyline)
        let farDist = EdgePathCalculator.distanceFromPoint(CGPoint(x: 25, y: 50), toPolyline: polyline)
        #expect(abs(nearDist - 4) < 0.001)
        #expect(farDist > 40)
    }
}
