import Foundation
import AppKit
import PDFKit

/// Representa o estado preservado de um documento aberto em uma aba.
public final class DocumentTabState: @unchecked Sendable {
    public var fileItem: FileItem
    public var pdfDocument: PDFDocument?
    public var documentText: String
    public var detectedEncoding: String.Encoding
    public var detectedEncodingName: String
    public var isDirty: Bool
    public var pdfCurrentPage: Int
    public var pdfTotalPages: Int
    public var pdfScaleFactor: CGFloat
    public var pdfAutoScales: Bool

    public init(
        fileItem: FileItem,
        pdfDocument: PDFDocument? = nil,
        documentText: String = "",
        detectedEncoding: String.Encoding = .utf8,
        detectedEncodingName: String = "UTF-8",
        isDirty: Bool = false,
        pdfCurrentPage: Int = 1,
        pdfTotalPages: Int = 1,
        pdfScaleFactor: CGFloat = 1.0,
        pdfAutoScales: Bool = true
    ) {
        self.fileItem = fileItem
        self.pdfDocument = pdfDocument
        self.documentText = documentText
        self.detectedEncoding = detectedEncoding
        self.detectedEncodingName = detectedEncodingName
        self.isDirty = isDirty
        self.pdfCurrentPage = pdfCurrentPage
        self.pdfTotalPages = pdfTotalPages
        self.pdfScaleFactor = pdfScaleFactor
        self.pdfAutoScales = pdfAutoScales
    }
}

/// Representa uma aba aberta na barra superior de documentos.
public struct DocumentTab: Identifiable, Hashable, Sendable {
    public let id: URL
    public var fileItem: FileItem
    public var isDirty: Bool

    public var title: String {
        fileItem.name
    }

    public var fileExtension: String {
        fileItem.fileExtension
    }

    public init(fileItem: FileItem, isDirty: Bool = false) {
        self.id = fileItem.url
        self.fileItem = fileItem
        self.isDirty = isDirty
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DocumentTab, rhs: DocumentTab) -> Bool {
        lhs.id == rhs.id
    }
}
