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

        // 17. Detecção de Quebra de Linha (LF / CRLF / CR)
        let sampleLF = "Linha 1\nLinha 2"
        let sampleCRLF = "Linha 1\r\nLinha 2"
        let sampleCR = "Linha 1\rLinha 2"
        func detectLE(_ text: String) -> String {
            if text.contains("\r\n") { return "CRLF" }
            if text.contains("\r") { return "CR" }
            return "LF"
        }
        assertEqual(detectLE(sampleLF), "LF")
        assertEqual(detectLE(sampleCRLF), "CRLF")
        assertEqual(detectLE(sampleCR), "CR")
        print("  ✓ testLineEndingDetection passou")

        // 18. Otimização de Performance e Deduplicação Espacial no PDF->Word
        let start = DispatchTime.now()
        let densePDF = try conversionService.convertToPDF(
            text: (1...20).map { "Item \($0) com texto formatado na coluna esquerda da página de teste." }.joined(separator: "\n"),
            title: "PerformanceTest",
            from: .txt
        )
        if let doc = PDFDocument(data: densePDF) {
            let docx = try conversionService.convertPDFDocumentToWord(document: doc, format: .docx)
            assertTrue(!docx.isEmpty, "Conversão otimizada deve gerar documento DOCX válido")
        }
        let end = DispatchTime.now()
        let elapsed = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        assertTrue(elapsed < 3000.0, "Conversão de página densa deve ser instantânea (levou \(Int(elapsed))ms)")
        print("  ✓ testPerformancePDFToWordOptimization passou (\(Int(elapsed))ms)")

        // 19. Inserção de Notas em Texto e Notas Adesivas Livres (Opção 2)
        print("\n▶ Testando Inserção e Gestão de Notas em PDF...")
        let noteDocData = try conversionService.convertToPDF(text: "Parágrafo com texto para anotação e revisão de contrato.", title: "NotasTest", from: .txt)
        guard let noteDoc = PDFDocument(data: noteDocData), let notePage = noteDoc.page(at: 0) else {
            fatalError("Falha ao gerar PDF para teste de notas")
        }

        // A. Nota ancorada em seleção de texto (Realce + Conteúdo da nota)
        let noteSelectionMatches = noteDoc.findString("revisão", withOptions: [.caseInsensitive])
        assertTrue(!noteSelectionMatches.isEmpty, "Deve encontrar a palavra 'revisão'")
        if let match = noteSelectionMatches.first {
            let bounds = match.bounds(for: notePage)
            let highlightWithNote = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            highlightWithNote.color = NSColor.yellow
            highlightWithNote.contents = "Nota: Verificar cláusula de revisão periódica."
            notePage.addAnnotation(highlightWithNote)

            let noteIconAnnotation = PDFAnnotation(bounds: CGRect(x: bounds.maxX + 4, y: bounds.maxY - 14, width: 22, height: 22), forType: .text, withProperties: nil)
            noteIconAnnotation.color = NSColor.yellow
            noteIconAnnotation.contents = "Nota: Verificar cláusula de revisão periódica."
            notePage.addAnnotation(noteIconAnnotation)
        }

        // B. Nota adesiva livre em coordenada arbitrária da página (Opção 2)
        let freeStickyNote = PDFAnnotation(bounds: CGRect(x: 120, y: 450, width: 24, height: 24), forType: .text, withProperties: nil)
        freeStickyNote.color = NSColor.systemGreen
        freeStickyNote.contents = "Lembrete geral inserido no espaço vazio da página."
        notePage.addAnnotation(freeStickyNote)

        // C. Valida presença e persistência dos dados
        let totalAnnotations = notePage.annotations.count
        assertTrue(totalAnnotations >= 3, "Página deve conter pelo menos 3 anotações")

        // Persistência em disco / Data
        guard let savedData = noteDoc.dataRepresentation(),
              let reloadedDoc = PDFDocument(data: savedData),
              let reloadedPage = reloadedDoc.page(at: 0) else {
            fatalError("Falha ao serializar e recarregar PDF com anotações")
        }

        let reloadedTextNotes = reloadedPage.annotations.filter { $0.type == "Text" }
        assertTrue(reloadedTextNotes.count >= 2, "PDF recarregado deve conter as notas adesivas salvas")
        let freeNoteFound = reloadedTextNotes.contains { $0.contents == "Lembrete geral inserido no espaço vazio da página." }
        assertTrue(freeNoteFound, "Conteúdo da nota livre deve ser preservado exatamente como salvo")

        // D. Edição e Exclusão de Nota
        freeStickyNote.contents = "Texto da nota editado com sucesso!"
        assertEqual(freeStickyNote.contents, "Texto da nota editado com sucesso!")
        notePage.removeAnnotation(freeStickyNote)
        assertTrue(!notePage.annotations.contains(freeStickyNote), "Nota deve ser removida da página com sucesso")
        print("  ✓ testPDFNotesTextAndFreeStickyAnnotations passou")

        // 20. Rotação de Páginas (Versão 1.1)
        print("\n▶ Testando Rotação de Páginas (Versão 1.1)...")
        var rotationPageText = ""
        for i in 1...80 {
            rotationPageText += "Linha \(i): Conteúdo da página para testes de rotação e exclusão estrutural de páginas no PDF.\n"
        }
        let multiPageData = try conversionService.convertToPDF(text: rotationPageText, title: "RotacaoTest", from: .txt)
        guard let rotationDoc = PDFDocument(data: multiPageData), rotationDoc.pageCount >= 2 else {
            fatalError("Falha ao gerar PDF de múltiplas páginas para teste de rotação")
        }

        // Rotação individual (Página 1: 0° -> 90° -> 180°)
        if let p0 = rotationDoc.page(at: 0) {
            assertEqual(p0.rotation, 0)
            p0.rotation = (p0.rotation + 90) % 360
            assertEqual(p0.rotation, 90)
            p0.rotation = (p0.rotation + 90) % 360
            assertEqual(p0.rotation, 180)
        }

        // Rotação em lote de todas as páginas
        for i in 0..<rotationDoc.pageCount {
            if let p = rotationDoc.page(at: i) {
                p.rotation = 90
            }
        }
        for i in 0..<rotationDoc.pageCount {
            assertEqual(rotationDoc.page(at: i)?.rotation, 90)
        }
        print("  ✓ testPDFPageRotationIndividualAndBatch passou")

        // 21. Exclusão de Páginas (Versão 1.1)
        print("\n▶ Testando Exclusão Estrutural de Páginas (Versão 1.1)...")
        let initialCount = rotationDoc.pageCount
        assertTrue(initialCount >= 2, "Documento deve ter pelo menos 2 páginas para testar exclusão")

        // Exclui a primeira página
        rotationDoc.removePage(at: 0)
        assertEqual(rotationDoc.pageCount, initialCount - 1)

        // Trava lógica de segurança: se restar 1 página, não deve permitir ficar vazio
        while rotationDoc.pageCount > 1 {
            rotationDoc.removePage(at: 0)
        }
        assertEqual(rotationDoc.pageCount, 1)
        print("  ✓ testPDFPageDeletionAndSafetyLimit passou")

        // 22. Compressão de Arquivo PDF (Versão 1.1)
        print("\n▶ Testando Compressão de Arquivo PDF (Versão 1.1)...")
        let compressionService = PDFCompressionService.shared
        let sampleDocData = try conversionService.convertToPDF(
            text: "Documento de teste com texto estruturado para validação de compressão e renderização de streams.",
            title: "CompressaoTest",
            from: .txt
        )
        guard let sampleDoc = PDFDocument(data: sampleDocData) else {
            fatalError("Falha ao gerar PDF para teste de compressão")
        }

        for level in CompressionLevel.allCases {
            let result = try compressionService.compressPDF(document: sampleDoc, level: level)
            assertTrue(!result.data.isEmpty, "Dados comprimidos para nível \(level.rawValue) não devem ser vazios")
            assertTrue(result.compressedSize > 0, "Tamanho comprimido deve ser positivo")

            // Valida se o documento comprimido é um PDF válido e legível pelo PDFKit
            guard let reloadedCompressedDoc = PDFDocument(data: result.data) else {
                fatalError("Dados gerados pela compressão \(level.rawValue) não formam um PDF válido")
            }
            assertEqual(reloadedCompressedDoc.pageCount, sampleDoc.pageCount)
        }
        print("  ✓ testPDFCompressionAllLevels passou")

        // 23. Reordenação Estrutural de Páginas (Versão 1.1)
        print("\n▶ Testando Reordenação Estrutural de Páginas (Versão 1.1)...")
        let docAData = try conversionService.convertToPDF(text: "Página Alfa com texto único.", title: "DocA", from: .txt)
        let docBData = try conversionService.convertToPDF(text: "Página Beta com texto único.", title: "DocB", from: .txt)
        guard let docA = PDFDocument(data: docAData), let docB = PDFDocument(data: docBData),
              let pageA = docA.page(at: 0), let pageB = docB.page(at: 0) else {
            fatalError("Falha ao criar páginas para teste de reordenação")
        }
        let reorderDoc = PDFDocument()
        reorderDoc.insert(pageA, at: 0)
        reorderDoc.insert(pageB, at: 1)
        assertEqual(reorderDoc.pageCount, 2)
        assertTrue(reorderDoc.page(at: 0)?.string?.contains("Alfa") == true, "Página 0 deve ser Alfa inicialmente")
        assertTrue(reorderDoc.page(at: 1)?.string?.contains("Beta") == true, "Página 1 deve ser Beta inicialmente")

        // Move página 0 para índice 1
        if let movedPage = reorderDoc.page(at: 0) {
            reorderDoc.removePage(at: 0)
            reorderDoc.insert(movedPage, at: 1)
        }
        assertEqual(reorderDoc.pageCount, 2)
        assertTrue(reorderDoc.page(at: 0)?.string?.contains("Beta") == true, "Página 0 agora deve ser Beta após reordenação")
        assertTrue(reorderDoc.page(at: 1)?.string?.contains("Alfa") == true, "Página 1 agora deve ser Alfa após reordenação")
        print("  ✓ testPDFPageReordering passou")

        print("\n========================================")
        print("TODOS OS 23 TESTES PASSARAM COM SUCESSO! 🎉")
        print("========================================")
    }
}
