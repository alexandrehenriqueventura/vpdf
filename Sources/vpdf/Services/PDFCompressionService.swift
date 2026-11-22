import Foundation
import AppKit
import PDFKit

/// Protocolo para o serviço de compressão de documentos PDF.
public protocol PDFCompressionServiceProtocol {
    func compressPDF(document: PDFDocument, level: CompressionLevel) throws -> (data: Data, originalSize: Int64, compressedSize: Int64)
}

/// Serviço de alta performance para otimização e compressão de arquivos PDF.
public final class PDFCompressionService: PDFCompressionServiceProtocol {
    public static let shared = PDFCompressionService()

    public init() {}

    /// Comprime um documento PDF de acordo com o nível selecionado, otimizando streams e renderização gráfica.
    public func compressPDF(
        document: PDFDocument,
        level: CompressionLevel
    ) throws -> (data: Data, originalSize: Int64, compressedSize: Int64) {
        let originalData = document.dataRepresentation() ?? Data()
        let originalSize = Int64(originalData.count)

        guard document.pageCount > 0 else {
            throw AppError.conversionFailed("O documento PDF não contém páginas para compressão.")
        }

        let compressedData = NSMutableData()
        guard let consumer = CGDataConsumer(data: compressedData as CFMutableData) else {
            throw AppError.conversionFailed("Falha ao inicializar o consumidor de dados para compressão de PDF.")
        }

        var firstPageBox = document.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &firstPageBox, nil) else {
            throw AppError.conversionFailed("Falha ao criar o contexto gráfico de gravação do PDF comprimido.")
        }

        let scale = level.renderScale
        let quality = level.compressionQuality

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            var pageRect = page.bounds(for: .mediaBox)
            if pageRect.width <= 0 || pageRect.height <= 0 {
                pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
            }

            // Considera a rotação atual da página
            let rotation = page.rotation
            let isTransposed = (rotation == 90 || rotation == 270)
            let targetSize = CGSize(
                width: isTransposed ? pageRect.height : pageRect.width,
                height: isTransposed ? pageRect.width : pageRect.height
            )

            let pixelWidth = max(1, Int(targetSize.width * scale))
            let pixelHeight = max(1, Int(targetSize.height * scale))

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

            guard let bitmapContext = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                continue
            }

            // Fundo branco limpo
            bitmapContext.setFillColor(NSColor.white.cgColor)
            bitmapContext.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

            // Configura escala e rotação no bitmap
            bitmapContext.saveGState()
            bitmapContext.scaleBy(x: scale, y: scale)

            switch rotation {
            case 90:
                bitmapContext.translateBy(x: targetSize.width, y: 0)
                bitmapContext.rotate(by: .pi / 2)
            case 180:
                bitmapContext.translateBy(x: targetSize.width, y: targetSize.height)
                bitmapContext.rotate(by: .pi)
            case 270:
                bitmapContext.translateBy(x: 0, y: targetSize.height)
                bitmapContext.rotate(by: 3 * .pi / 2)
            default:
                break
            }

            // Renderiza conteúdo da página e anotações
            page.draw(with: .mediaBox, to: bitmapContext)
            bitmapContext.restoreGState()

            guard let renderedImage = bitmapContext.makeImage() else {
                continue
            }

            // Converte para JPEG com a taxa de compressão definida
            let nsImage = NSImage(cgImage: renderedImage, size: targetSize)
            guard let tiffRep = nsImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffRep),
                  let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality]),
                  let compressedImage = NSImage(data: jpegData) else {
                continue
            }

            // Grava a página no novo PDF comprimido
            let mediaBox = CGRect(origin: .zero, size: targetSize)
            pdfContext.beginPDFPage(nil)

            let prevGraphicsContext = NSGraphicsContext.current
            let pdfGraphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = pdfGraphicsContext

            compressedImage.draw(in: mediaBox)

            NSGraphicsContext.current = prevGraphicsContext
            pdfContext.endPDFPage()
        }

        pdfContext.closePDF()

        let finalData = compressedData as Data
        let compressedSize = Int64(finalData.count)

        return (data: finalData, originalSize: originalSize, compressedSize: compressedSize)
    }
}
