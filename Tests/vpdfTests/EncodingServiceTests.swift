import XCTest
@testable import vpdf

final class EncodingServiceTests: XCTestCase {
    var service: EncodingService!

    override func setUp() {
        super.setUp()
        service = EncodingService()
    }

    func testEmptyData() throws {
        let result = try service.decode(data: Data())
        XCTAssertEqual(result.content, "")
        XCTAssertEqual(result.encoding, .utf8)
    }

    func testUTF8WithoutBOM() throws {
        let originalText = "Testando texto em português com acentuação: Olá, você e maçã!"
        let data = originalText.data(using: .utf8)!

        let result = try service.decode(data: data)
        XCTAssertEqual(result.content, originalText)
        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.encodingName, "UTF-8")
    }

    func testUTF8WithBOM() throws {
        let originalText = "Documento UTF-8 com BOM."
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(originalText.data(using: .utf8)!)

        let result = try service.decode(data: data)
        XCTAssertEqual(result.content, originalText)
        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.encodingName, "UTF-8 (BOM)")
    }

    func testUTF16LEWithBOM() throws {
        let originalText = "Texto em UTF-16 Little Endian."
        var data = Data([0xFF, 0xFE])
        data.append(originalText.data(using: .utf16LittleEndian)!)

        let result = try service.decode(data: data)
        XCTAssertEqual(result.content, originalText)
        XCTAssertEqual(result.encodingName, "UTF-16 LE")
    }

    func testUTF16BEWithBOM() throws {
        let originalText = "Texto em UTF-16 Big Endian."
        var data = Data([0xFE, 0xFF])
        data.append(originalText.data(using: .utf16BigEndian)!)

        let result = try service.decode(data: data)
        XCTAssertEqual(result.content, originalText)
        XCTAssertEqual(result.encodingName, "UTF-16 BE")
    }

    func testWindows1252Encoding() throws {
        // O símbolo do Euro (€ = 0x80) e aspas curvas ("”" = 0x94) são exclusivos do Windows-1252 na faixa 0x80-0x9F
        let originalText = "Preço em euros: €150. Aspas: “moderno”."
        guard let data = originalText.data(using: .windowsCP1252) else {
            XCTFail("Não foi possível gerar dados em Windows-1252")
            return
        }

        let result = try service.decode(data: data)
        XCTAssertEqual(result.content, originalText)
        XCTAssertEqual(result.encoding, .windowsCP1252)
        XCTAssertEqual(result.encodingName, "Windows-1252")
    }

    func testISO88591Latin1Encoding() throws {
        let originalText = "Café, açúcar e maçã."
        guard let data = originalText.data(using: .isoLatin1) else {
            XCTFail("Não foi possível gerar dados em ISO-8859-1")
            return
        }

        let result = try service.decode(data: data)
        XCTAssertEqual(result.content, originalText)
        XCTAssertTrue(result.encoding == .isoLatin1 || result.encoding == .windowsCP1252)
    }
}
