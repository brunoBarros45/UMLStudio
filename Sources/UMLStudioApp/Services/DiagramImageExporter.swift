import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import UMLApplication
import UMLDomain

public enum DiagramExportError: LocalizedError {
    case emptyDiagram
    case failedToRenderImage
    case failedToCreatePDFContext

    public var errorDescription: String? {
        switch self {
        case .emptyDiagram:
            return "El diagrama no contiene elementos para exportar."
        case .failedToRenderImage:
            return "No se pudo rasterizar la imagen del diagrama."
        case .failedToCreatePDFContext:
            return "No se pudo inicializar el documento PDF."
        }
    }
}

/// Renders an off-screen print-quality representation of a `UMLDiagram` to PNG (2x Retina) or Vector PDF.
@MainActor
public enum DiagramImageExporter {
    public static func exportPNG(diagram: UMLDiagram, model: UMLModel, to url: URL) throws {
        let (view, size) = try makePrintableContent(diagram: diagram, model: model)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(size)

        guard let cgImage = renderer.cgImage else {
            throw DiagramExportError.failedToRenderImage
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw DiagramExportError.failedToRenderImage
        }
        try pngData.write(to: url, options: .atomic)
    }

    public static func exportPDF(diagram: UMLDiagram, model: UMLModel, to url: URL) throws {
        let (view, size) = try makePrintableContent(diagram: diagram, model: model)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)

        var pdfError: Error?
        renderer.render { renderedSize, renderContext in
            var mediaBox = CGRect(origin: .zero, size: renderedSize)
            guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
                pdfError = DiagramExportError.failedToCreatePDFContext
                return
            }
            let pageOptions: [CFString: Any] = [kCGPDFContextMediaBox: mediaBox]
            pdfContext.beginPDFPage(pageOptions as CFDictionary)
            renderContext(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }

        if let pdfError {
            throw pdfError
        }
    }

    private static func makePrintableContent(diagram: UMLDiagram, model: UMLModel) throws -> (some View, CGSize) {
        guard !diagram.nodes.isEmpty else {
            throw DiagramExportError.emptyDiagram
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for node in diagram.nodes {
            guard let classifier = model.classifier(for: node.classifierID) else { continue }
            let box = node.boundingBox(for: classifier)
            minX = min(minX, box.minX)
            minY = min(minY, box.minY)
            maxX = max(maxX, box.maxX)
            maxY = max(maxY, box.maxY)
        }

        let padding: CGFloat = 64
        let originOffset = CGPoint(x: padding - minX, y: padding - minY)
        let width = max(400, (maxX - minX) + padding * 2)
        let height = max(300, (maxY - minY) + padding * 2)
        let canvasSize = CGSize(width: width, height: height)

        let view = PrintableDiagramView(
            diagram: diagram,
            model: model,
            originOffset: originOffset,
            canvasSize: canvasSize
        )
        return (view, canvasSize)
    }
}

private struct PrintableDiagramView: View {
    let diagram: UMLDiagram
    let model: UMLModel
    let originOffset: CGPoint
    let canvasSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            // Subtle title header in exported output
            Text(diagram.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.gray.opacity(0.75))
                .padding(.top, 18)
                .padding(.leading, 24)

            RelationshipEdgeCanvasLayer(
                diagram: shiftedDiagram,
                model: model,
                selectedRelationshipID: nil,
                canvasBackground: .white
            )

            ForEach(shiftedDiagram.nodes) { node in
                if let classifier = model.classifier(for: node.classifierID) {
                    ClassifierCardView(
                        classifier: classifier,
                        node: node,
                        isSelected: false,
                        isHovered: false,
                        showPorts: false,
                        isPrintMode: true
                    )
                    .position(
                        x: node.position.x + node.boundingBox(for: classifier).width / 2,
                        y: node.position.y + node.boundingBox(for: classifier).height / 2
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private var shiftedDiagram: UMLDiagram {
        var copy = diagram
        copy.nodes = diagram.nodes.map { node in
            var shifted = node
            shifted.position = CGPoint(x: node.position.x + originOffset.x, y: node.position.y + originOffset.y)
            return shifted
        }
        return copy
    }
}
