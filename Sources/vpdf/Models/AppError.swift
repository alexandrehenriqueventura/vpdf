import Foundation

/// Erros de aplicação apresentados ao usuário de forma amigável.
public enum AppError: LocalizedError, Identifiable, Sendable {
    case permissionDenied(URL)
    case fileNotFound(URL)
    case invalidEncoding(URL)
    case conversionFailed(String)
    case saveFailed(String)
    case securityScopedBookmarkFailed(String)

    public var id: String {
        switch self {
        case .permissionDenied(let url): return "permissionDenied-\(url.path)"
        case .fileNotFound(let url): return "fileNotFound-\(url.path)"
        case .invalidEncoding(let url): return "invalidEncoding-\(url.path)"
        case .conversionFailed(let reason): return "conversionFailed-\(reason)"
        case .saveFailed(let reason): return "saveFailed-\(reason)"
        case .securityScopedBookmarkFailed(let reason): return "bookmarkFailed-\(reason)"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let url):
            return "Permissão de acesso negada ao item '\(url.lastPathComponent)'. Por favor, reabra a pasta raiz via menu."
        case .fileNotFound(let url):
            return "O arquivo '\(url.lastPathComponent)' não foi encontrado no disco."
        case .invalidEncoding(let url):
            return "Não foi possível identificar a codificação do arquivo '\(url.lastPathComponent)'. Formato não suportado."
        case .conversionFailed(let reason):
            return "Falha durante a conversão do documento: \(reason)"
        case .saveFailed(let reason):
            return "Não foi possível salvar as alterações no arquivo: \(reason)"
        case .securityScopedBookmarkFailed(let reason):
            return "Falha ao persistir permissão segura de acesso: \(reason)"
        }
    }
}
