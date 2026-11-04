import SwiftUI
import AppKit
import PDFKit

/// Visualizador nativo de documentos PDF utilizando PDFView do PDFKit (alta performance, renderização vetorial).
public struct PDFViewerRepresentable: NSViewRepresentable {
    public let document: PDFDocument?
    public var searchText: String
    @Binding public var scaleFactor: CGFloat
    @Binding public var autoScales: Bool
    @Binding public var currentPage: Int
    @Binding public var totalPages: Int

    public init(
        document: PDFDocument?,
        searchText: String = "",
        scaleFactor: Binding<CGFloat>,
        autoScales: Binding<Bool>,
        currentPage: Binding<Int>,
        totalPages: Binding<Int>
    ) {
        self.document = document
        self.searchText = searchText
        self._scaleFactor = scaleFactor
        self._autoScales = autoScales
        self._currentPage = currentPage
        self._totalPages = totalPages
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = autoScales
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        context.coordinator.attach(to: pdfView)
        return pdfView
    }

    public func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self

        if pdfView.document !== document {
            pdfView.document = document
            if autoScales {
                pdfView.autoScales = true
            }
            if let doc = document {
                let total = max(1, doc.pageCount)
                let current = (doc.index(for: pdfView.currentPage ?? doc.page(at: 0) ?? PDFPage())) + 1
                if totalPages != total { totalPages = total }
                if currentPage != current { currentPage = max(1, current) }
            }
        }

        // Sincroniza estado de Zoom
        if autoScales {
            if !pdfView.autoScales {
                pdfView.autoScales = true
            }
        } else {
            if pdfView.autoScales {
                pdfView.autoScales = false
            }
            if abs(pdfView.scaleFactor - scaleFactor) > 0.01 {
                pdfView.scaleFactor = scaleFactor
            }
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
        private var isUpdatingFromNotification = false

        init(_ parent: PDFViewerRepresentable) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to view: PDFView) {
            self.pdfView = view
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pdfScaleChanged(_:)),
                name: .PDFViewScaleChanged,
                object: view
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pdfPageChanged(_:)),
                name: .PDFViewPageChanged,
                object: view
            )
        }

        @objc private func pdfPageChanged(_ notification: Notification) {
            guard let view = pdfView, let doc = view.document, let current = view.currentPage else { return }
            let pageIndex = doc.index(for: current)
            let total = max(1, doc.pageCount)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let newPage = pageIndex + 1
                if self.parent.currentPage != newPage {
                    self.parent.currentPage = newPage
                }
                if self.parent.totalPages != total {
                    self.parent.totalPages = total
                }
            }
        }

        @objc private func pdfScaleChanged(_ notification: Notification) {
            guard let view = pdfView else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if abs(self.parent.scaleFactor - view.scaleFactor) > 0.01 {
                    self.parent.scaleFactor = view.scaleFactor
                }
                if self.parent.autoScales != view.autoScales {
                    self.parent.autoScales = view.autoScales
                }
            }
        }
    }
}
