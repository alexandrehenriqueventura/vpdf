import XCTest
import AppKit
import PDFKit
@testable import vpdf

final class ConversionServiceTests: XCTestCase {
    var service: ConversionService!

    override func setUp() {
        super.setUp()
        service = ConversionService()
    }

    func testPlainTextConversion() throws {
        let text = "Texto simples de teste.\nLinha 2."
        let data = try service.convertToPlainText(text: text)
        let resultString = String(data: data, encoding: .utf8)
        XCTAssertEqual(resultString, text)
    }

    func testRTFConversion() throws {
        let text = "Texto para conversão RTF com formatação básica."
        let data = try service.convertToRTF(text: text, from: .txt)

        XCTAssertFalse(data.isEmpty)
        let rtfHeader = String(data: data.prefix(10), encoding: .ascii) ?? ""
        XCTAssertTrue(rtfHeader.hasPrefix("{\\rtf1"), "Cabeçalho RTF deve iniciar com {\\rtf1")

        // Valida que NSAttributedString é capaz de carregar o RTF gerado
        let attributedString = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        XCTAssertTrue(attributedString.string.contains("Texto para conversão RTF"))
    }

    func testHTMLConversion() throws {
        let text = """
        # Título Principal
        Este é um parágrafo de introdução.
        > Uma citação relevante
        ```swift
        let x = 42
        ```
        """

        let data = try service.convertToHTML(text: text, title: "Documento de Teste", from: .md)
        XCTAssertFalse(data.isEmpty)

        guard let html = String(data: data, encoding: .utf8) else {
            XCTFail("HTML gerado não está em UTF-8")
            return
        }

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<title>Documento de Teste</title>"))
        XCTAssertTrue(html.contains("<h1>Título Principal</h1>"))
        XCTAssertTrue(html.contains("<blockquote>Uma citação relevante</blockquote>"))
        XCTAssertTrue(html.contains("<pre><code>let x = 42</code></pre>"))
    }

    func testPDFConversion() throws {
        let text = "Relatório executivo gerado pelo vpdf.\nContendo informações estruturadas e paginação."
        let data = try service.convertToPDF(text: text, title: "Relatório", from: .txt)

        XCTAssertFalse(data.isEmpty)
        guard let pdfDoc = PDFDocument(data: data) else {
            XCTFail("PDFDocument não conseguiu decodificar os dados gerados")
            return
        }

        XCTAssertEqual(pdfDoc.pageCount, 1)
        guard let page = pdfDoc.page(at: 0) else {
            XCTFail("Primeira página do PDF não encontrada")
            return
        }
        XCTAssertTrue(page.string?.contains("Relatório executivo") ?? false)
    }

    func testMultiPagePDFConversion() throws {
        // Gera um texto longo que ultrapasse uma página A4
        var longText = ""
        for i in 1...150 {
            longText += "Linha \(i): Este é um parágrafo longo para garantir que a renderização do CoreText divida as páginas corretamente no formato A4.\n"
        }

        let data = try service.convertToPDF(text: longText, title: "Documento Longo", from: .txt)
        guard let pdfDoc = PDFDocument(data: data) else {
            XCTFail("PDFDocument falhou")
            return
        }

        XCTAssertGreaterThan(pdfDoc.pageCount, 1, "Documento de 150 linhas deve gerar mais de 1 página A4")
    }
}
