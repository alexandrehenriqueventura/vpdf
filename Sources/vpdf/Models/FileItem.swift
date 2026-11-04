import Foundation

/// Representa um nó (pasta ou arquivo) na árvore de diretórios do aplicativo.
public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public var children: [FileItem]?
    public var isLoaded: Bool

    public init(
        url: URL,
        isDirectory: Bool,
        children: [FileItem]? = nil,
        isLoaded: Bool = false
    ) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.children = children
        self.isLoaded = isLoaded
    }

    public var fileExtension: String {
        url.pathExtension.lowercased()
    }

    /// Ícone SF Symbol apropriado para o tipo de arquivo ou pasta.
    public var systemIconName: String {
        if isDirectory {
            return "folder"
        }
        switch fileExtension {
        case "txt":
            return "doc.plaintext"
        case "md", "markdown":
            return "doc.text"
        case "rtf":
            return "doc.richtext"
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "pdf":
            return "doc.viewfinder"
        default:
            return "doc"
        }
    }

    public static func placeholder(for parentURL: URL) -> FileItem {
        FileItem(
            url: parentURL.appendingPathComponent(".loading-placeholder"),
            isDirectory: false,
            isLoaded: true
        )
    }

    public var isPlaceholder: Bool {
        name == ".loading-placeholder"
    }
}
