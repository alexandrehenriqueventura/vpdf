import SwiftUI
import AppKit
import PDFKit

/// Visualizador nativo de documentos PDF utilizando PDFView do PDFKit (alta performance, renderização vetorial).
public struct PDFViewerRepresentable: NSViewRepresentable {
    public let document: PDFDocument?
    public var searchText: String

    public init(document: PDFDocument?, searchText: String = "") {
        self.document = document
        self.searchText = searchText
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    public func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
            pdfView.autoScales = true
        }

        // Busca e destaque de texto no PDF
        if !searchText.isEmpty && searchText != context.coordinator.lastSearchQuery {
            context.coordinator.lastSearchQuery = searchText
            if let selections = document?.findString(searchText, withOptions: [.caseInsensitive]) {
                pdfView.highlightedSelections = selections
                if let first = selections.first {
                    pdfView.go(to: first)
                    pdfView.setCurrentSelection(first, animate: true)
                }
            }
        } else if searchText.isEmpty && !context.coordinator.lastSearchQuery.isEmpty {
            context.coordinator.lastSearchQuery = ""
            pdfView.highlightedSelections = nil
            pdfView.clearSelection()
        }
    }

    public final class Coordinator: NSObject {
        var parent: PDFViewerRepresentable
        weak var pdfView: PDFView?
        var lastSearchQuery: String = ""

        init(_ parent: PDFViewerRepresentable) {
            self.parent = parent
        }
    }
}
