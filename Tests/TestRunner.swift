import Foundation
import AppKit
import PDFKit

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
    if actual != expected {
        print("❌ FALHA [Linha \(line)]: \(message) (Esperado: \(expected), Recebido: \(actual))")
        exit(1)
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
    if !condition {
        print("❌ FALHA [Linha \(line)]: \(message)")
        exit(1)
    }
}

@main
struct TestRunner {
    static func main() throws {
        print("========================================")
        print("INICIANDO SUÍTES DE TESTES UNITÁRIOS")
        print("========================================")

        let encodingService = EncodingService()
        let conversionService = ConversionService()

        // Testes EncodingService
        print("▶ Testando EncodingService...")

        // 1. Vazio
        let emptyResult = try encodingService.decode(data: Data())
        assertEqual(emptyResult.content, "")
        assertEqual(emptyResult.encoding, .utf8)
        print("  ✓ testEmptyData passou")

        // 2. UTF-8 sem BOM
        let originalUTF8 = "Testando texto em português com acentuação: Olá, você e maçã!"
        let utf8Result = try encodingService.decode(data: originalUTF8.data(using: .utf8)!)
        assertEqual(utf8Result.content, originalUTF8)
        assertEqual(utf8Result.encoding, .utf8)
        assertEqual(utf8Result.encodingName, "UTF-8")
        print("  ✓ testUTF8WithoutBOM passou")

        // 3. UTF-8 com BOM
        var utf8BOMData = Data([0xEF, 0xBB, 0xBF])
        utf8BOMData.append(originalUTF8.data(using: .utf8)!)
        let utf8BOMResult = try encodingService.decode(data: utf8BOMData)
        assertEqual(utf8BOMResult.content, originalUTF8)
        assertEqual(utf8BOMResult.encoding, .utf8)
        assertEqual(utf8BOMResult.encodingName, "UTF-8 (BOM)")
        print("  ✓ testUTF8WithBOM passou")

        // 4. UTF-16 LE
        var utf16LEData = Data([0xFF, 0xFE])
        utf16LEData.append("Texto UTF-16 LE".data(using: .utf16LittleEndian)!)
        let utf16LEResult = try encodingService.decode(data: utf16LEData)
        assertEqual(utf16LEResult.content, "Texto UTF-16 LE")
        assertEqual(utf16LEResult.encodingName, "UTF-16 LE")
        print("  ✓ testUTF16LEWithBOM passou")

        // 5. UTF-16 BE
        var utf16BEData = Data([0xFE, 0xFF])
        utf16BEData.append("Texto UTF-16 BE".data(using: .utf16BigEndian)!)
        let utf16BEResult = try encodingService.decode(data: utf16BEData)
        assertEqual(utf16BEResult.content, "Texto UTF-16 BE")
        assertEqual(utf16BEResult.encodingName, "UTF-16 BE")
        print("  ✓ testUTF16BEWithBOM passou")

        // 6. Windows-1252
        let winText = "Preço em euros: €150. Aspas: “moderno”."
        let winData = winText.data(using: .windowsCP1252)!
        let winResult = try encodingService.decode(data: winData)
        assertEqual(winResult.content, winText)
        assertEqual(winResult.encoding, .windowsCP1252)
        assertEqual(winResult.encodingName, "Windows-1252")
        print("  ✓ testWindows1252Encoding passou")

        // 7. ISO-8859-1 (Latin1)
        let latinText = "Café, açúcar e maçã."
        let latinData = latinText.data(using: .isoLatin1)!
        let latinResult = try encodingService.decode(data: latinData)
        assertEqual(latinResult.content, latinText)
        assertTrue(latinResult.encoding == .isoLatin1 || latinResult.encoding == .windowsCP1252)
        print("  ✓ testISO88591Latin1Encoding passou")

        // Testes ConversionService
        print("\n▶ Testando ConversionService...")

        // 8. Plain text
        let txtData = try conversionService.convertToPlainText(text: "Texto simples de teste.\nLinha 2.")
        assertEqual(String(data: txtData, encoding: .utf8), "Texto simples de teste.\nLinha 2.")
        print("  ✓ testPlainTextConversion passou")

        // 9. RTF
        let rtfData = try conversionService.convertToRTF(text: "Texto para conversão RTF com formatação básica.", from: .txt)
        assertTrue(!rtfData.isEmpty)
        let rtfHeader = String(data: rtfData.prefix(10), encoding: .ascii) ?? ""
        assertTrue(rtfHeader.hasPrefix("{\\rtf1"), "Cabeçalho RTF deve iniciar com {\\rtf1")
        let attrString = try NSAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        assertTrue(attrString.string.contains("Texto para conversão RTF"))
        print("  ✓ testRTFConversion passou")

        // 10. HTML
        let mdInput = """
        # Título Principal
        Este é um parágrafo de introdução.
        > Uma citação relevante
        ```swift
        let x = 42
        ```
        """
        let htmlData = try conversionService.convertToHTML(text: mdInput, title: "Documento de Teste", from: .md)
        assertTrue(!htmlData.isEmpty)
        let htmlString = String(data: htmlData, encoding: .utf8)!
        assertTrue(htmlString.contains("<!DOCTYPE html>"))
        assertTrue(htmlString.contains("<title>Documento de Teste</title>"))
        assertTrue(htmlString.contains("<h1>Título Principal</h1>"))
        assertTrue(htmlString.contains("<blockquote>Uma citação relevante</blockquote>"))
        assertTrue(htmlString.contains("<pre><code>let x = 42</code></pre>"))
        print("  ✓ testHTMLConversion passou")

        // 11. PDF Single Page
        let pdfSingleData = try conversionService.convertToPDF(text: "Relatório executivo gerado pelo vpdf.\nContendo informações estruturadas.", title: "Relatório", from: .txt)
        assertTrue(!pdfSingleData.isEmpty)
        guard let pdfDoc = PDFDocument(data: pdfSingleData) else {
            fatalError("PDF inválido")
        }
        assertEqual(pdfDoc.pageCount, 1)
        assertTrue(pdfDoc.page(at: 0)?.string?.contains("Relatório executivo") ?? false)
        print("  ✓ testPDFConversion (1 página) passou")

        // 12. PDF Multi Page
        var multiPageText = ""
        for i in 1...150 {
            multiPageText += "Linha \(i): Este é um parágrafo longo para garantir que a renderização do CoreText divida as páginas corretamente no formato A4.\n"
        }
        let pdfMultiData = try conversionService.convertToPDF(text: multiPageText, title: "Documento Longo", from: .txt)
        guard let multiDoc = PDFDocument(data: pdfMultiData) else {
            fatalError("PDF multipágina inválido")
        }
        assertTrue(multiDoc.pageCount > 1, "Deve gerar mais de 1 página A4 (gerou \(multiDoc.pageCount))")
        print("  ✓ testMultiPagePDFConversion (\(multiDoc.pageCount) páginas) passou")

        // 13. DOCX para PDF
        let wordOriginalText = "Capítulo de Demonstração Word (.docx)\nEste documento foi gerado e convertido nativamente para PDF no macOS."
        let wordAttr = NSAttributedString(string: wordOriginalText, attributes: [
            .font: NSFont(name: "Helvetica", size: 14) ?? NSFont.systemFont(ofSize: 14)
        ])
        let wordDocxData = try wordAttr.data(
            from: NSRange(location: 0, length: wordAttr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
        let wordPdfData = try conversionService.convertWordToPDF(data: wordDocxData, format: .docx)
        assertTrue(!wordPdfData.isEmpty, "Dados do PDF gerado a partir do Word não devem ser vazios")
        guard let wordPdfDoc = PDFDocument(data: wordPdfData) else {
            fatalError("PDF gerado a partir de DOCX é inválido")
        }
        assertTrue(wordPdfDoc.pageCount >= 1)
        assertTrue(wordPdfDoc.page(at: 0)?.string?.contains("Demonstração Word") ?? false)
        print("  ✓ testWordDocxToPDFConversion (\(wordPdfDoc.pageCount) página) passou")

        // 14. PDF para Word DOCX preservando formatação rica
        let testPDFForDocx = try conversionService.convertToPDF(text: "Título Principal do Teste\nSegundo parágrafo detalhado.", title: "DocxTest", from: .txt)
        guard let sourcePdf = PDFDocument(data: testPDFForDocx) else {
            fatalError("Falha ao criar PDF para teste de exportação DOCX")
        }
        let exportedWordData = try conversionService.convertPDFDocumentToWord(document: sourcePdf, format: .docx)
        assertTrue(!exportedWordData.isEmpty, "Dados do DOCX exportado do PDF não devem ser vazios")
        let readBackDocx = try NSAttributedString(
            data: exportedWordData,
            options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
            documentAttributes: nil
        )
        assertTrue(readBackDocx.string.contains("Título Principal do Teste"))
        print("  ✓ testPDFToWordDocxPreservingFormatting passou")

        // 15. Reconstrução 2D de tabelas e planilhas em DOCX
        let tablePdfData = NSMutableData()
        if let consumer = CGDataConsumer(data: tablePdfData as CFMutableData) {
            var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
            if let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
                pdfContext.beginPage(mediaBox: &mediaBox)
                let gc = NSGraphicsContext(cgContext: pdfContext, flipped: false)
                let prevGc = NSGraphicsContext.current
                NSGraphicsContext.current = gc
                let col1 = NSAttributedString(string: "Item", attributes: [.font: NSFont(name: "Helvetica", size: 12) ?? NSFont.systemFont(ofSize: 12)])
                col1.draw(at: NSPoint(x: 50, y: 750))
                let col2 = NSAttributedString(string: "Preço", attributes: [.font: NSFont(name: "Helvetica", size: 12) ?? NSFont.systemFont(ofSize: 12)])
                col2.draw(at: NSPoint(x: 250, y: 750))
                NSGraphicsContext.current = prevGc
                pdfContext.endPage()
                pdfContext.closePDF()

                if let tablePdfDoc = PDFDocument(data: tablePdfData as Data) {
                    let docxTableData = try conversionService.convertPDFDocumentToWord(document: tablePdfDoc, format: .docx)
                    let readTable = try NSAttributedString(
                        data: docxTableData,
                        options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                        documentAttributes: nil
                    )
                    assertTrue(readTable.string.contains("Item") && readTable.string.contains("Preço"), "Tabela deve conter os itens das colunas")
                    print("  ✓ testPDFToWord2DTableReconstruction passou")
                }
            }
        }

        // 16. Busca de texto e anotações nativas em PDF
        let searchDocData = try conversionService.convertToPDF(text: "Primeiro Slide de Apresentação.\nContém termos importantes para pesquisa e destaque.", title: "BuscaTest", from: .txt)
        guard let searchDoc = PDFDocument(data: searchDocData) else {
            fatalError("Falha ao gerar PDF para teste de busca")
        }
        let matches = searchDoc.findString("Slide", withOptions: [.caseInsensitive])
        assertTrue(matches.count >= 1, "Busca deve encontrar pelo menos 1 ocorrência de 'Slide'")
        if let firstMatch = matches.first, let page = firstMatch.pages.first {
            let bounds = firstMatch.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = NSColor.yellow
            page.addAnnotation(annotation)
            assertTrue(page.annotations.contains(annotation), "Anotação de realce deve ser vinculada à página")
        }
        print("  ✓ testPDFSearchAndNativeAnnotations passou")

        print("\n========================================")
        print("TODOS OS 16 TESTES PASSARAM COM SUCESSO! 🎉")
        print("========================================")
    }
}
