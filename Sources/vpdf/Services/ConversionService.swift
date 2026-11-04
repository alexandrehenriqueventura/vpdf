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

    /// Conversão para PDF (.pdf) via CoreText e PDFKit com suporte a paginação A4
    public func convertToPDF(
        text: String,
        title: String,
        from sourceFormat: ConversionFormat
    ) throws -> Data {
        let attr = buildAttributedString(from: text, format: sourceFormat)
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

        let baseFont = NSFont.systemFont(ofSize: 11.5)
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
