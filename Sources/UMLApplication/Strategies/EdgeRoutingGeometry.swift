import CoreGraphics
import Foundation
import UMLDomain

/// Pure geometric helper for exact ray-box intersection and UML edge routing paths.
public enum EdgePathCalculator {
    /// Computes the intersection point where the segment from `rect.center` toward `outsidePoint`
    /// crosses the perimeter of `rect`.
    public static func rectIntersection(from center: CGPoint, toward target: CGPoint, rect: CGRect) -> CGPoint {
        let dx = target.x - center.x
        let dy = target.y - center.y

        guard abs(dx) > 0.0001 || abs(dy) > 0.0001 else {
            return CGPoint(x: rect.maxX, y: rect.midY)
        }

        let halfW = rect.width / 2.0
        let halfH = rect.height / 2.0

        var scaleX = CGFloat.greatestFiniteMagnitude
        var scaleY = CGFloat.greatestFiniteMagnitude

        if abs(dx) > 0.0001 {
            scaleX = halfW / abs(dx)
        }
        if abs(dy) > 0.0001 {
            scaleY = halfH / abs(dy)
        }

        let t = min(scaleX, scaleY)
        return CGPoint(x: center.x + dx * t, y: center.y + dy * t)
    }

    /// Computes polyline points connecting `sourceRect` to `targetRect` according to `routingStyle`.
    public static func computePathPoints(
        routingStyle: EdgeRoutingStyle,
        sourceRect: CGRect,
        targetRect: CGRect,
        waypoints: [CGPoint] = [],
        isSelfLoop: Bool = false
    ) -> [CGPoint] {
        if isSelfLoop {
            return selfLoopPoints(for: sourceRect)
        }

        let sourceCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)

        if !waypoints.isEmpty {
            let start = rectIntersection(from: sourceCenter, toward: waypoints[0], rect: sourceRect)
            let end = rectIntersection(from: targetCenter, toward: waypoints[waypoints.count - 1], rect: targetRect)
            return [start] + waypoints + [end]
        }

        switch routingStyle {
        case .straight:
            let start = rectIntersection(from: sourceCenter, toward: targetCenter, rect: sourceRect)
            let end = rectIntersection(from: targetCenter, toward: sourceCenter, rect: targetRect)
            return [start, end]

        case .orthogonal:
            return orthogonalPoints(from: sourceRect, to: targetRect)
        }
    }

    /// Computes clean orthogonal L-shaped or Z-shaped segments exiting optimal rectangle sides.
    private static func orthogonalPoints(from sourceRect: CGRect, to targetRect: CGRect) -> [CGPoint] {
        let sCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        let tCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
        let dx = tCenter.x - sCenter.x
        let dy = tCenter.y - sCenter.y

        if abs(dx) >= abs(dy) {
            // Horizontal dominant layout
            let goingRight = dx >= 0
            let startX = goingRight ? sourceRect.maxX : sourceRect.minX
            let endX = goingRight ? targetRect.minX : targetRect.maxX
            let start = CGPoint(x: startX, y: sCenter.y)
            let end = CGPoint(x: endX, y: tCenter.y)

            if abs(start.y - end.y) < 4 {
                return [start, CGPoint(x: end.x, y: start.y)]
            }

            let midX = (start.x + end.x) / 2.0
            return [
                start,
                CGPoint(x: midX, y: start.y),
                CGPoint(x: midX, y: end.y),
                end
            ]
        } else {
            // Vertical dominant layout
            let goingDown = dy >= 0
            let startY = goingDown ? sourceRect.maxY : sourceRect.minY
            let endY = goingDown ? targetRect.minY : targetRect.maxY
            let start = CGPoint(x: sCenter.x, y: startY)
            let end = CGPoint(x: tCenter.x, y: endY)

            if abs(start.x - end.x) < 4 {
                return [start, CGPoint(x: start.x, y: end.y)]
            }

            let midY = (start.y + end.y) / 2.0
            return [
                start,
                CGPoint(x: start.x, y: midY),
                CGPoint(x: end.x, y: midY),
                end
            ]
        }
    }

    private static func selfLoopPoints(for rect: CGRect) -> [CGPoint] {
        let exitPoint = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3)
        let outRight = CGPoint(x: rect.maxX + 42, y: exitPoint.y)
        let outBottom = CGPoint(x: rect.maxX + 42, y: rect.minY - 28)
        let overTop = CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.minY - 28)
        let entryPoint = CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.minY)
        return [exitPoint, outRight, outBottom, overTop, entryPoint]
    }

    /// Computes shortest Euclidean distance from a point to a polyline for edge selection hit-testing.
    public static func distanceFromPoint(_ point: CGPoint, toPolyline points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return .greatestFiniteMagnitude }
        var minDistance = CGFloat.greatestFiniteMagnitude
        for i in 0..<(points.count - 1) {
            let d = distanceFromPoint(point, toSegmentStart: points[i], end: points[i + 1])
            minDistance = min(minDistance, d)
        }
        return minDistance
    }

    public static func distanceFromPoint(_ p: CGPoint, toSegmentStart a: CGPoint, end b: CGPoint) -> CGFloat {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let lengthSq = abx * abx + aby * aby
        if lengthSq < 0.0001 {
            return hypot(p.x - a.x, p.y - a.y)
        }
        let t = max(0, min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq))
        let projX = a.x + t * abx
        let projY = a.y + t * aby
        return hypot(p.x - projX, p.y - projY)
    }

    /// Computes the midpoint along a polyline for placing the relationship name label.
    public static func polylineMidpoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        if points.count == 1 { return points[0] }

        var totalLength: CGFloat = 0
        var segmentLengths: [CGFloat] = []
        for i in 0..<(points.count - 1) {
            let len = hypot(points[i + 1].x - points[i].x, points[i + 1].y - points[i].y)
            segmentLengths.append(len)
            totalLength += len
        }

        guard totalLength > 0.001 else { return points[0] }
        let targetDist = totalLength / 2.0
        var accumulated: CGFloat = 0

        for i in 0..<segmentLengths.count {
            let len = segmentLengths[i]
            if accumulated + len >= targetDist && len > 0 {
                let ratio = (targetDist - accumulated) / len
                return CGPoint(
                    x: points[i].x + (points[i + 1].x - points[i].x) * ratio,
                    y: points[i].y + (points[i + 1].y - points[i].y) * ratio
                )
            }
            accumulated += len
        }
        return points[points.count / 2]
    }
}
