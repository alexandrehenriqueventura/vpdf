import Foundation

/// Resultado da decodificação contendo o texto e a codificação detectada.
public struct DetectedText: Sendable, Equatable {
    public let content: String
    public let encoding: String.Encoding
    public let encodingName: String

    public init(content: String, encoding: String.Encoding, encodingName: String) {
        self.content = content
        self.encoding = encoding
        self.encodingName = encodingName
    }
}

/// Serviço responsável por identificar a codificação e decodificar arquivos de texto.
public final class EncodingService: Sendable {
    public static let shared = EncodingService()

    public init() {}

    /// Detecta a codificação dos dados e retorna o texto decodificado.
    /// Ordem de tentativa: BOMs -> UTF-8 -> Windows-1252 / ISO-8859-1 -> UTF-16 fallback.
    public func decode(data: Data) throws -> DetectedText {
        if data.isEmpty {
            return DetectedText(content: "", encoding: .utf8, encodingName: "UTF-8")
        }

        // 1. Verificação de Byte Order Mark (BOM)
        if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
            let subData = data.subdata(in: 3..<data.count)
            if let str = String(data: subData, encoding: .utf8) {
                return DetectedText(content: str, encoding: .utf8, encodingName: "UTF-8 (BOM)")
            }
        }

        if data.count >= 2 && data[0] == 0xFF && data[1] == 0xFE {
            let subData = data.subdata(in: 2..<data.count)
            if let str = String(data: subData, encoding: .utf16LittleEndian) {
                return DetectedText(content: str, encoding: .utf16LittleEndian, encodingName: "UTF-16 LE")
            }
        }

        if data.count >= 2 && data[0] == 0xFE && data[1] == 0xFF {
            let subData = data.subdata(in: 2..<data.count)
            if let str = String(data: subData, encoding: .utf16BigEndian) {
                return DetectedText(content: str, encoding: .utf16BigEndian, encodingName: "UTF-16 BE")
            }
        }

        // 2. Detecção de UTF-16 sem BOM (padrão de bytes nulos intercalados)
        if data.count >= 4 {
            if data[1] == 0 && data[3] == 0 && data[0] != 0 {
                if let str = String(data: data, encoding: .utf16LittleEndian) {
                    return DetectedText(content: str, encoding: .utf16LittleEndian, encodingName: "UTF-16 LE")
                }
            } else if data[0] == 0 && data[2] == 0 && data[1] != 0 {
                if let str = String(data: data, encoding: .utf16BigEndian) {
                    return DetectedText(content: str, encoding: .utf16BigEndian, encodingName: "UTF-16 BE")
                }
            }
        }

        // 3. Validação estrita de UTF-8
        if let utf8String = String(data: data, encoding: .utf8) {
            return DetectedText(content: utf8String, encoding: .utf8, encodingName: "UTF-8")
        }

        // 4. Detecção de Windows-1252 vs ISO-8859-1
        // Windows-1252 atribui caracteres específicos à faixa 0x80...0x9F (ex: € é 0x80, … é 0x85)
        let containsWindows1252SpecificBytes = data.contains { byte in
            (0x80...0x9F).contains(byte)
        }

        if containsWindows1252SpecificBytes {
            if let winString = String(data: data, encoding: .windowsCP1252) {
                return DetectedText(content: winString, encoding: .windowsCP1252, encodingName: "Windows-1252")
            }
        }

        // 5. Tenta ISO-8859-1 (Latin1)
        if let latin1String = String(data: data, encoding: .isoLatin1) {
            return DetectedText(content: latin1String, encoding: .isoLatin1, encodingName: "ISO-8859-1")
        }

        // 6. Fallback Windows-1252
        if let winString = String(data: data, encoding: .windowsCP1252) {
            return DetectedText(content: winString, encoding: .windowsCP1252, encodingName: "Windows-1252")
        }

        // 7. Tentativa genérica do sistema
        var usedEncoding: String.Encoding = .utf8
        if let string = try? String(contentsOf: createTemporaryURL(with: data), usedEncoding: &usedEncoding) {
            return DetectedText(
                content: string,
                encoding: usedEncoding,
                encodingName: name(for: usedEncoding)
            )
        }

        throw AppError.invalidEncoding(URL(fileURLWithPath: "arquivo"))
    }

    private func createTemporaryURL(with data: Data) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        return tempURL
    }

    private func name(for encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .windowsCP1252: return "Windows-1252"
        case .isoLatin1: return "ISO-8859-1"
        case .utf16, .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian: return "UTF-16 BE"
        case .ascii: return "US-ASCII"
        default: return encoding.description
        }
    }
}
