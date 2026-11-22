import Foundation

/// Níveis de compressão disponíveis para otimização de arquivos PDF.
public enum CompressionLevel: String, CaseIterable, Identifiable {
    case low = "Leve"
    case balanced = "Equilibrada (Recomendada)"
    case strong = "Forte"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    public var description: String {
        switch self {
        case .low:
            return "Mantém alta nitidez gráfica (~150 DPI). Ideal para documentos que serão impressos."
        case .balanced:
            return "Redução equilibrada (~120 DPI) com excelente legibilidade. Ideal para e-mails e visualização em tela."
        case .strong:
            return "Compressão máxima (~96 DPI) com foco em obter o menor tamanho de arquivo possível."
        }
    }

    /// Fator de escala da renderização de imagem para o nível de compressão.
    public var renderScale: CGFloat {
        switch self {
        case .low: return 1.6
        case .balanced: return 1.25
        case .strong: return 1.0
        }
    }

    /// Qualidade de compressão JPEG das imagens rasterizadas (0.0 a 1.0).
    public var compressionQuality: CGFloat {
        switch self {
        case .low: return 0.75
        case .balanced: return 0.60
        case .strong: return 0.40
        }
    }
}
