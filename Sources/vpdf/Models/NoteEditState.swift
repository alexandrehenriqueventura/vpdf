import Foundation
import AppKit
import PDFKit

/// Representa o estado ativo de criação ou edição de uma nota em documento PDF.
public struct NoteEditState: Identifiable {
    public let id = UUID()
    public var title: String
    public var text: String
    public var color: HighlightColorOption
    public var isExisting: Bool

    public var targetPage: PDFPage?
    public var targetPoint: CGPoint?
    public var targetSelection: PDFSelection?
    public var existingAnnotation: PDFAnnotation?

    public init(
        title: String,
        text: String = "",
        color: HighlightColorOption = .yellow,
        isExisting: Bool = false,
        targetPage: PDFPage? = nil,
        targetPoint: CGPoint? = nil,
        targetSelection: PDFSelection? = nil,
        existingAnnotation: PDFAnnotation? = nil
    ) {
        self.title = title
        self.text = text
        self.color = color
        self.isExisting = isExisting
        self.targetPage = targetPage
        self.targetPoint = targetPoint
        self.targetSelection = targetSelection
        self.existingAnnotation = existingAnnotation
    }
}
