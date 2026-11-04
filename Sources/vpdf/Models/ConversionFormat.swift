import Foundation
import UniformTypeIdentifiers

/// Formatos de arquivo suportados para leitura, exibição e conversão.
public enum ConversionFormat: String, CaseIterable, Identifiable, Sendable {
    case txt
    case md
    case rtf
    case html
    case docx
    case doc
    case pdf

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .txt:  return "TXT (Texto Simples)"
        case .md:   return "Markdown"
        case .rtf:  return "RTF (Rich Text)"
        case .html: return "HTML5"
        case .docx: return "Word (.docx)"
        case .doc:  return "Word 97-2004 (.doc)"
        case .pdf:  return "PDF"
        }
    }

    public var fileExtension: String {
        rawValue
    }

    public var uniformType: UTType {
        switch self {
        case .txt:  return .plainText
        case .md:   return .init(filenameExtension: "md") ?? .plainText
        case .rtf:  return .rtf
        case .html: return .html
        case .docx: return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .doc:  return UTType("com.microsoft.word.doc") ?? .data
        case .pdf:  return .pdf
        }
    }

    public static func from(url: URL) -> ConversionFormat? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt": return .txt
        case "md", "markdown": return .md
        case "rtf": return .rtf
        case "html", "htm": return .html
        case "docx": return .docx
        case "doc": return .doc
        case "pdf": return .pdf
        default: return nil
        }
    }
}
