import Foundation
import AppKit
import PDFKit

/// Serviço responsável por converter textos entre formatos (TXT, MD, RTF, HTML e PDF)
/// de forma assíncrona fora da thread principal.
public final class ConversionService: Sendable {
    public static let shared = ConversionService()

    public init() {}

    /// Converte o texto fornecido para o formato de destino.
    public func convert(
        text: String,
        from sourceFormat: ConversionFormat,
        to targetFormat: ConversionFormat,
        documentTitle: String = "Documento"
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            switch targetFormat {
            case .txt:
                return try self.convertToPlainText(text: text)

            case .md:
                return try self.convertToMarkdown(text: text, from: sourceFormat)

            case .rtf:
                return try self.convertToRTF(text: text, from: sourceFormat)

            case .html:
                return try self.convertToHTML(text: text, title: documentTitle, from: sourceFormat)

            case .docx, .doc:
                return try self.convertToDocx(text: text, from: sourceFormat)

            case .pdf:
                return try self.convertToPDF(text: text, title: documentTitle, from: sourceFormat)
            }
        }.value
    }

    // MARK: - Conversões Específicas

    /// Conversão para Texto Simples (.txt)
    public func convertToPlainText(text: String) throws -> Data {
        guard let data = text.data(using: .utf8) else {
            throw AppError.conversionFailed("Falha ao codificar texto em UTF-8.")
        }
        return data
    }

    /// Conversão para Markdown (.md)
    public func convertToMarkdown(text: String, from sourceFormat: ConversionFormat) throws -> Data {
        // Se já for Markdown ou TXT, exporta diretamente
        guard let data = text.data(using: .utf8) else {
            throw AppError.conversionFailed("Falha ao codificar Markdown em UTF-8.")
        }
        return data
    }

    /// Conversão para Rich Text (.rtf) via NSAttributedString
    public func convertToRTF(text: String, from sourceFormat: ConversionFormat) throws -> Data {
        let attributedString = buildAttributedString(from: text, format: sourceFormat)
        do {
            let range = NSRange(location: 0, length: attributedString.length)
            return try attributedString.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        } catch {
            throw AppError.conversionFailed("Erro na geração do RTF: \(error.localizedDescription)")
        }
    }

    /// Conversão para Word (.docx) via NSAttributedString nativo
    public func convertToDocx(text: String, from sourceFormat: ConversionFormat) throws -> Data {
        let attributedString = buildAttributedString(from: text, format: sourceFormat)
        do {
            let range = NSRange(location: 0, length: attributedString.length)
            return try attributedString.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
            )
        } catch {
            throw AppError.conversionFailed("Erro na exportação para Word (.docx): \(error.localizedDescription)")
        }
    }

    /// Converte um PDFDocument diretamente para Word (.docx / .doc) reconstruindo a estrutura 2D:
    /// - Reconstitui tabelas, planilhas e calendários com colunas alinhadas via tabulações (`\t`).
    /// - Elimina quebras artificiais de linhas no meio de parágrafos, permitindo fluxo contínuo.
    /// - Preserva hierarquia de fontes (títulos, subtítulos, corpo), pesos (negrito/itálico) e cores.
    public func convertPDFDocumentToWord(
        document: PDFDocument,
        format: ConversionFormat
    ) throws -> Data {
        let combined = NSMutableAttributedString()

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            let pageStructuredAttr = extractStructuredContentFromPDFPage(page)
            if pageStructuredAttr.length > 0 {
                let normalized = normalizeFontsForExport(pageStructuredAttr)
                combined.append(normalized)
            } else if let fallback = page.attributedString, fallback.length > 0 {
                let normalized = normalizeFontsForExport(fallback)
                combined.append(normalized)
            } else if let pageString = page.string, !pageString.isEmpty {
                let fallbackAttr = buildAttributedString(from: pageString, format: .txt)
                combined.append(fallbackAttr)
            }

            // Insere quebra limpa de página entre páginas sucessivas
            if pageIndex < document.pageCount - 1 {
                let pageBreak = NSAttributedString(
                    string: "\n\n",
                    attributes: [
                        .font: NSFont(name: "Helvetica", size: 11) ?? NSFont.systemFont(ofSize: 11)
                    ]
                )
                combined.append(pageBreak)
            }
        }

        guard combined.length > 0 else {
            throw AppError.conversionFailed("O documento PDF não possui texto selecionável para conversão.")
        }

        let docType: NSAttributedString.DocumentType = (format == .doc) ? .docFormat : .officeOpenXML

        do {
            let range = NSRange(location: 0, length: combined.length)
            return try combined.data(
                from: range,
                documentAttributes: [.documentType: docType]
            )
        } catch {
            throw AppError.conversionFailed("Erro na exportação do PDF para Word: \(error.localizedDescription)")
        }
    }

    /// Reconstrói o layout bidimensional (2D) de uma página de PDF:
    /// identifica tabelas/planilhas colunares e mescla linhas de parágrafos fluidamente.
    private func extractStructuredContentFromPDFPage(_ page: PDFPage) -> NSAttributedString {
        struct LineBlock {
            let text: String
            let bounds: CGRect
            let attributedString: NSAttributedString?
        }

        let totalChars = page.numberOfCharacters
        guard totalChars > 0 else { return NSAttributedString() }

        var lineBlocks: [LineBlock] = []
        var lastBounds: CGRect?
        var seenBoundsKeys = Set<String>()

        // 1. Identifica os blocos de texto geométricos via selectionForLine
        // Otimização O(1): se o caractere atual pertence à mesma linha geométrica recém-encontrada,
        // evita a chamada cara de selectionForLine (que é O(layout) no PDFKit).
        for i in 0..<totalChars {
            let b = page.characterBounds(at: i)
            guard b.width > 0 && b.height > 0 else { continue }
            let pt = CGPoint(x: b.midX, y: b.midY)

            if let last = lastBounds, last.insetBy(dx: -1.0, dy: -1.0).contains(pt) {
                continue
            }

            if let sel = page.selectionForLine(at: pt), let s = sel.string, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let sb = sel.bounds(for: page)
                lastBounds = sb

                // Chave espacial discretizada para deduplicação O(1) em vez de varredura linear O(N)
                let key = "\(Int(sb.origin.x.rounded()))_\(Int(sb.origin.y.rounded()))_\(Int(sb.width.rounded()))"
                if seenBoundsKeys.insert(key).inserted {
                    lineBlocks.append(LineBlock(text: s, bounds: sb, attributedString: sel.attributedString))
                }
            }
        }

        guard !lineBlocks.isEmpty else { return NSAttributedString() }

        // 2. Agrupa em linhas horizontais pelo eixo Y (do topo da página para a base)
        let yTolerance: CGFloat = 4.5
        var rows: [[LineBlock]] = []
        let sortedBlocks = lineBlocks.sorted { a, b in
            if abs(a.bounds.midY - b.bounds.midY) <= yTolerance {
                return a.bounds.minX < b.bounds.minX
            }
            return a.bounds.midY > b.bounds.midY
        }

        for block in sortedBlocks {
            if let rIdx = rows.indices.first(where: {
                guard let first = rows[$0].first else { return false }
                return abs(first.bounds.midY - block.bounds.midY) <= yTolerance
            }) {
                rows[rIdx].append(block)
            } else {
                rows.append([block])
            }
        }

        for i in 0..<rows.count {
            rows[i].sort { $0.bounds.minX < $1.bounds.minX }
        }

        // 3. Monta o texto atribuído separando colunas por tabulação e fluidificando parágrafos
        let resultAttr = NSMutableAttributedString()

        for (rIdx, row) in rows.enumerated() {
            let rowAttr = NSMutableAttributedString()
            let isTable = row.count > 1

            for (bIdx, block) in row.enumerated() {
                if bIdx > 0 {
                    rowAttr.append(NSAttributedString(string: "\t"))
                }
                if let a = block.attributedString {
                    rowAttr.append(a)
                } else {
                    rowAttr.append(NSAttributedString(string: block.text))
                }
            }

            // Para linhas de tabela/planilha, define tabStops regulares para alinhamento uniforme no Word
            if isTable {
                let style = NSMutableParagraphStyle()
                var tabs: [NSTextTab] = []
                for colIndex in 1...16 {
                    tabs.append(NSTextTab(type: .leftTabStopType, location: CGFloat(colIndex * 70)))
                }
                style.tabStops = tabs
                rowAttr.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: rowAttr.length))
            }

            resultAttr.append(rowAttr)

            // 4. Decisão de quebra de linha vs continuação de parágrafo
            if rIdx < rows.count - 1 {
                let nextRow = rows[rIdx + 1]
                let currentY = row.first?.bounds.midY ?? 0
                let nextY = nextRow.first?.bounds.midY ?? 0
                let vGap = currentY - nextY
                let isNextTable = nextRow.count > 1
                let rowText = row.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                let endsWithPunct = [".", "!", "?", ":", ";"].contains(where: { rowText.hasSuffix($0) })

                // Mantém quebra de linha se for tabela, parágrafo terminado, título ou espaçamento grande
                if isTable || isNextTable || endsWithPunct || vGap > 22.0 || rowText.count < 35 {
                    resultAttr.append(NSAttributedString(string: "\n"))
                } else {
                    // Texto corrido: une com espaço suave sem quebrar a linha no Word
                    resultAttr.append(NSAttributedString(string: " "))
                }
            }
        }

        return resultAttr
    }

    /// Normaliza nomes de fontes internas do macOS para tipografia universal (Helvetica/Arial),
    /// preservando rigorosamente o tamanho exato em pontos (pointSize), negrito, itálico e cores com cache de instâncias.
    private func normalizeFontsForExport(_ attr: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attr)
        let fullRange = NSRange(location: 0, length: result.length)
        var fontCache: [String: NSFont] = [:]

        result.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
            let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
            let size = max(6.0, font.pointSize)
            let cacheKey = "\(isBold ? "b" : "_")_\(isItalic ? "i" : "_")_\(size)"

            let normalizedFont: NSFont
            if let cached = fontCache[cacheKey] {
                normalizedFont = cached
            } else {
                let resolved: NSFont
                if isBold && isItalic {
                    resolved = NSFontManager.shared.font(withFamily: "Helvetica", traits: [.boldFontMask, .italicFontMask], weight: 7, size: size) ?? font
                } else if isBold {
                    resolved = NSFontManager.shared.font(withFamily: "Helvetica", traits: .boldFontMask, weight: 7, size: size) ?? font
                } else if isItalic {
                    resolved = NSFontManager.shared.font(withFamily: "Helvetica", traits: .italicFontMask, weight: 5, size: size) ?? font
                } else {
                    resolved = NSFont(name: "Helvetica", size: size) ?? font
                }
                fontCache[cacheKey] = resolved
                normalizedFont = resolved
            }

            result.removeAttribute(.font, range: range)
            result.addAttribute(.font, value: normalizedFont, range: range)
        }

        return result
    }

    /// Conversão para HTML5 (.html) autocontido com CSS refinado
    public func convertToHTML(
        text: String,
        title: String,
        from sourceFormat: ConversionFormat
    ) throws -> Data {
        let escapedTitle = escapeHTML(title)
        let bodyContent = formatTextAsHTMLBody(text: text, isMarkdown: sourceFormat == .md)

        let htmlString = """
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escapedTitle)</title>
            <style>
                :root {
                    color-scheme: light dark;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    max-width: 860px;
                    margin: 3rem auto;
                    padding: 0 1.5rem;
                    line-height: 1.7;
                    color: #1d1d1f;
                    background-color: #fcfcfd;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #f5f5f7;
                        background-color: #1c1c1e;
                    }
                    code, pre {
                        background-color: #2c2c2e;
                    }
                    blockquote {
                        border-left-color: #38383a;
                        color: #a1a1a6;
                    }
                }
                h1, h2, h3, h4, h5, h6 {
                    line-height: 1.3;
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    font-weight: 600;
                }
                p {
                    margin: 0.8em 0;
                }
                code {
                    font-family: "SF Mono", Menlo, Monaco, Consolas, monospace;
                    font-size: 0.9em;
                    background-color: #f0f0f2;
                    padding: 0.2em 0.4em;
                    border-radius: 4px;
                }
                pre {
                    background-color: #f0f0f2;
                    padding: 1rem;
                    border-radius: 6px;
                    overflow-x: auto;
                }
                pre code {
                    padding: 0;
                    background-color: transparent;
                }
                blockquote {
                    margin: 1.2em 0;
                    padding-left: 1rem;
                    border-left: 3px solid #d1d1d6;
                    color: #6e6e73;
                }
                hr {
                    border: none;
                    border-top: 1px solid #e5e5ea;
                    margin: 2rem 0;
                }
            </style>
        </head>
        <body>
            \(bodyContent)
        </body>
        </html>
        """

        guard let data = htmlString.data(using: .utf8) else {
            throw AppError.conversionFailed("Falha ao codificar documento HTML em UTF-8.")
        }
        return data
    }

    /// Converte um documento Word (.docx ou .doc) para PDF preservando a formatação do texto.
    public func convertWordToPDF(data: Data, format: ConversionFormat) throws -> Data {
        let docType: NSAttributedString.DocumentType
        switch format {
        case .doc:
            docType = .docFormat
        default:
            docType = .officeOpenXML
        }

        do {
            let attr = try NSAttributedString(
                data: data,
                options: [.documentType: docType],
                documentAttributes: nil
            )
            return try renderAttributedStringToPDF(attr)
        } catch {
            throw AppError.conversionFailed("Falha ao processar arquivo Word (\(format.rawValue)): \(error.localizedDescription)")
        }
    }

    /// Conversão para PDF (.pdf) via CoreText e PDFKit com suporte a paginação A4
    public func convertToPDF(
        text: String,
        title: String,
        from sourceFormat: ConversionFormat
    ) throws -> Data {
        let attr = buildAttributedString(from: text, format: sourceFormat)
        return try renderAttributedStringToPDF(attr)
    }

    /// Renderiza qualquer NSAttributedString em um PDF A4 de múltiplas páginas com CoreText.
    public func renderAttributedStringToPDF(_ attr: NSAttributedString) throws -> Data {
        let pdfData = NSMutableData()

        // Padrão A4: 595.2 x 841.8 pontos a 72 dpi
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 50.0
        let printableRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            throw AppError.conversionFailed("Não foi possível criar o contexto gráfico de renderização PDF.")
        }

        let framesetter = CTFramesetterCreateWithAttributedString(attr)
        var textIndex = 0
        let totalLength = attr.length

        // Se o texto for vazio, cria ao menos 1 página em branco válida
        if totalLength == 0 {
            context.beginPDFPage(nil)
            context.endPDFPage()
        } else {
            while textIndex < totalLength {
                context.beginPDFPage(nil)

                let path = CGPath(rect: printableRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRangeMake(textIndex, 0),
                    path,
                    nil
                )

                CTFrameDraw(frame, context)

                let visibleRange = CTFrameGetVisibleStringRange(frame)
                if visibleRange.length == 0 {
                    context.endPDFPage()
                    break
                }

                textIndex += visibleRange.length
                context.endPDFPage()
            }
        }

        context.closePDF()
        let resultData = pdfData as Data

        guard PDFDocument(data: resultData) != nil else {
            throw AppError.conversionFailed("O documento PDF gerado é inválido.")
        }

        return resultData
    }

    // MARK: - Helpers Internos

    private func buildAttributedString(from text: String, format: ConversionFormat) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.0
        paragraphStyle.paragraphSpacing = 8.0

        let baseFont = NSFont(name: "Helvetica", size: 11.5) ?? NSFont.systemFont(ofSize: 11.5)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }

    private func formatTextAsHTMLBody(text: String, isMarkdown: Bool) -> String {
        let lines = text.components(separatedBy: .newlines)
        var result: [String] = []
        var inCodeBlock = false
        var currentCodeBlock: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isMarkdown && trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    result.append("<pre><code>\(escapeHTML(currentCodeBlock.joined(separator: "\n")))</code></pre>")
                    currentCodeBlock.removeAll()
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                currentCodeBlock.append(line)
                continue
            }

            if trimmed.isEmpty {
                continue
            }

            if isMarkdown {
                if trimmed.hasPrefix("# ") {
                    result.append("<h1>\(escapeHTML(String(trimmed.dropFirst(2))))</h1>")
                } else if trimmed.hasPrefix("## ") {
                    result.append("<h2>\(escapeHTML(String(trimmed.dropFirst(3))))</h2>")
                } else if trimmed.hasPrefix("### ") {
                    result.append("<h3>\(escapeHTML(String(trimmed.dropFirst(4))))</h3>")
                } else if trimmed.hasPrefix("> ") {
                    result.append("<blockquote>\(escapeHTML(String(trimmed.dropFirst(2))))</blockquote>")
                } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    result.append("<ul><li>\(escapeHTML(String(trimmed.dropFirst(2))))</li></ul>")
                } else {
                    result.append("<p>\(escapeHTML(line))</p>")
                }
            } else {
                result.append("<p>\(escapeHTML(line))</p>")
            }
        }

        if inCodeBlock {
            result.append("<pre><code>\(escapeHTML(currentCodeBlock.joined(separator: "\n")))</code></pre>")
        }

        return result.joined(separator: "\n")
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
