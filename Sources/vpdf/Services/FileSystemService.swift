import Foundation
import AppKit

/// Serviço responsável por operações no sistema de arquivos, respeitando o App Sandbox e
/// gerenciando Security-Scoped Bookmarks para persistência de permissões entre sessões.
public final class FileSystemService: @unchecked Sendable {
    public static let shared = FileSystemService()

    private let bookmarkKey = "vpdf.securityScoped.lastDirectoryBookmark"
    private var activeSecurityScopedURL: URL?

    /// Extensões de arquivos suportados na listagem da barra lateral (apenas PDF e pastas).
    public static let supportedExtensions: Set<String> = [
        "pdf"
    ]

    public init() {}

    deinit {
        stopAccessingActiveSecurityScopedURL()
    }

    // MARK: - Security-Scoped Bookmarks & Permissions

    /// Abre o diálogo nativo NSOpenPanel para o usuário selecionar uma pasta.
    @MainActor
    public func selectFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Abrir Pasta"
        panel.message = "Selecione a pasta raiz que deseja explorar e editar:"

        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else {
            return nil
        }

        do {
            try persistBookmark(for: selectedURL)
            return selectedURL
        } catch {
            return selectedURL
        }
    }

    /// Salva o Security-Scoped Bookmark no UserDefaults para restaurar na próxima inicialização.
    public func persistBookmark(for url: URL) throws {
        stopAccessingActiveSecurityScopedURL()

        _ = url.startAccessingSecurityScopedResource()
        activeSecurityScopedURL = url

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            throw AppError.securityScopedBookmarkFailed(error.localizedDescription)
        }
    }

    /// Restaura o diretório previamente autorizado via Security-Scoped Bookmark.
    public func restorePersistedDirectory() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try? persistBookmark(for: url)
            }

            if url.startAccessingSecurityScopedResource() {
                activeSecurityScopedURL = url
                return url
            }
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }

        return nil
    }

    /// Encerra o acesso com escopo de segurança se ativo.
    public func stopAccessingActiveSecurityScopedURL() {
        if let url = activeSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
        }
    }

    // MARK: - Directory Inspection (Lazy Loading)

    /// Lista os filhos imediatos de um diretório de forma assíncrona (fora da main thread).
    public func contentsOfDirectory(at url: URL) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                throw AppError.fileNotFound(url)
            }

            let properties: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]

            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: properties,
                options: options
            ) else {
                throw AppError.permissionDenied(url)
            }

            var items: [FileItem] = []

            while let fileURL = enumerator.nextObject() as? URL {
                // Considera apenas filhos diretos (não recursivo no nível atual para manter o carregamento lazy)
                if fileURL.deletingLastPathComponent().path == url.path {
                    let resourceValues = try? fileURL.resourceValues(forKeys: Set(properties))
                    let isDirectory = resourceValues?.isDirectory ?? false
                    let isHidden = resourceValues?.isHidden ?? false

                    if !isHidden {
                        // Pastas sempre são exibidas; arquivos apenas se forem formatos de texto/documento suportados
                        let ext = fileURL.pathExtension.lowercased()
                        if isDirectory || Self.supportedExtensions.contains(ext) {
                            let placeholderChildren = isDirectory ? [FileItem.placeholder(for: fileURL)] : nil
                            items.append(FileItem(
                                url: fileURL,
                                isDirectory: isDirectory,
                                children: placeholderChildren,
                                isLoaded: false
                            ))
                        }
                    }
                }
            }

            // Ordena: pastas primeiro (alfabético), depois arquivos (alfabético)
            return items.sorted { a, b in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory && !b.isDirectory
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }.value
    }

    // MARK: - File I/O

    /// Lê os bytes brutos do arquivo em segundo plano.
    public func readFileData(at url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                throw AppError.fileNotFound(url)
            }

            do {
                return try Data(contentsOf: url)
            } catch {
                throw AppError.permissionDenied(url)
            }
        }.value
    }

    /// Grava texto no arquivo preservando a codificação especificada.
    public func saveText(_ text: String, to url: URL, encoding: String.Encoding) async throws {
        try await Task.detached(priority: .userInitiated) {
            guard let data = text.data(using: encoding) else {
                throw AppError.saveFailed("Incompatibilidade de codificação com o conteúdo informado.")
            }

            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw AppError.saveFailed(error.localizedDescription)
            }
        }.value
    }
}
